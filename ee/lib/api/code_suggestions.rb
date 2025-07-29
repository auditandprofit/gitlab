# frozen_string_literal: true

module API
  class CodeSuggestions < ::API::Base
    include APIGuard

    feature_category :code_suggestions

    # a limit used for overall body size when forwarding request to ai-assist
    MAX_BODY_SIZE = 600_000
    MAX_CONTENT_SIZE = 400_000

    allow_access_with_scope :ai_features

    before do
      authenticate!

      not_found_with_origin_header! unless Feature.enabled?(:ai_duo_code_suggestions_switch, type: :ops)

      unauthorized_with_origin_header! unless current_user.can?(:access_code_suggestions)
    end

    helpers do
      include Gitlab::Utils::StrongMemoize

      def completion_model_details
        ::CodeSuggestions::ModelDetails::CodeCompletion.new(current_user: current_user)
      end
      strong_memoize_attr :completion_model_details

      def project(project_path)
        strong_memoize_with(:project, project_path) do
          ::ProjectsFinder
            .new(
              params: { full_paths: [project_path] },
              current_user: current_user
            ).execute.first
        end
      end

      def ai_gateway_headers(headers, service)
        Gitlab::AiGateway.headers(
          user: current_user,
          service: service,
          agent: headers["User-Agent"],
          lsp_version: headers["X-Gitlab-Language-Server-Version"]
        ).merge(saas_headers).merge(model_config_headers).transform_values { |v| Array(v) }
      end

      def ai_gateway_public_headers(service_name)
        Gitlab::AiGateway.public_headers(user: current_user, service_name: service_name)
          .merge(saas_headers)
          .merge(model_config_headers)
          .merge('X-Gitlab-Authentication-Type' => 'oidc')
      end

      def saas_headers
        return {} unless Gitlab.com?

        {
          'X-Gitlab-Saas-Namespace-Ids' => '', # TODO: remove this header entirely once confirmed safe to do so
          # We're reusing the existing 'X-Gitlab-Saas-Duo-Pro-Namespace-Ids' header name
          # even though we're now combining duo_pro with duo_core_and_ent_namespace_ids.
          # This avoids the need for the data team to combine columns in reporting,
          # allowing the existing reporting pipeline to continue working seamlessly.
          'X-Gitlab-Saas-Duo-Pro-Namespace-Ids' => current_user.duo_available_namespace_ids.join(',')
        }
      end

      def model_config_headers
        model_prompt_cache_enabled = model_prompt_cache_enabled?(declared_params.fetch(:project_path))

        {
          # this config will decide if we allow the underlying model to cache the generated completion response
          'X-Gitlab-Model-Prompt-Cache-Enabled' => (!!model_prompt_cache_enabled).to_s
        }
      end

      def not_found_with_origin_header!
        header('X-GitLab-Error-Origin', 'monolith')
        not_found!
      end

      def unauthorized_with_origin_header!
        header('X-GitLab-Error-Origin', 'monolith')
        unauthorized!
      end

      def file_too_large_with_origin_header!
        header('X-GitLab-Error-Origin', 'monolith')
        file_too_large!
      end

      # Any Claude model (including failover provider) needs v3 of the code completion prompt
      # which isn't supported by direct access
      def forbid_direct_access?
        return true if Gitlab::CurrentSettings.disabled_direct_code_suggestions
        return true if Feature.enabled?(:incident_fail_over_completion_provider, current_user)
        return true if completion_model_details.user_group_with_claude_code_completion.present?
        return true if completion_model_details.any_user_groups_with_model_selected_for_completion?
        return true if ::Ai::AmazonQ.connected?

        false
      end

      def model_prompt_cache_enabled?(project_path)
        current_project = project(project_path) if project_path.present?

        if current_project.present?
          current_project.model_prompt_cache_enabled
        else
          Gitlab::CurrentSettings.model_prompt_cache_enabled
        end
      end
    end

    namespace 'code_suggestions' do
      resources :completions do
        params do
          requires :current_file, type: Hash do
            requires :file_name, type: String, limit: 255, desc: 'The name of the current file'
            requires :content_above_cursor, type: String, limit: MAX_CONTENT_SIZE, desc: 'The content above cursor'
            optional :content_below_cursor, type: String, limit: MAX_CONTENT_SIZE, desc: 'The content below cursor'
          end
          optional :intent, type: String, values:
            [
              ::CodeSuggestions::InstructionsExtractor::INTENT_COMPLETION,
              ::CodeSuggestions::InstructionsExtractor::INTENT_GENERATION
            ],
            desc: 'The intent of the completion request, current options are "completion" or "generation"'
          optional :generation_type, type: String, values: ::CodeSuggestions::Instruction::GENERATION_TRIGGER_TYPES,
            desc: 'The type of generation request'
          optional :stream, type: Boolean, default: false, desc: 'The option to stream code completion response'
          optional :project_path, type: String, desc: 'The path of the project',
            documentation: { example: 'namespace/project' }
          optional :user_instruction, type: String, limit: MAX_BODY_SIZE,
            desc: 'Additional instructions provided by a user'
          optional :context, type: Array, allow_blank: false, desc: 'List of related context parts' do
            requires :type, type: String,
              values: ::Ai::AdditionalContext::CODE_SUGGESTIONS_CONTEXT_TYPES.values,
              desc: 'The type of a related part of context'
            requires :name, type: String, limit: ::Ai::AdditionalContext::MAX_CONTEXT_TYPE_SIZE, allow_blank: false,
              desc: 'The name of a related part of context'
            requires :content, type: String, limit: ::Ai::AdditionalContext::MAX_BODY_SIZE, allow_blank: false,
              desc: 'The content of a part of context'
          end
        end
        post do
          check_rate_limit!(:code_suggestions_api_endpoint, scope: current_user) do
            Gitlab::InternalEvents.track_event(
              'code_suggestions_rate_limit_exceeded',
              user: current_user
            )

            header('X-GitLab-Error-Origin', 'monolith')
            render_api_error!({ error: _('This endpoint has been requested too many times. Try again later.') }, 429)
          end

          task = ::CodeSuggestions::TaskFactory.new(
            current_user,
            client: ::CodeSuggestions::Client.new(headers),
            params: declared_params(params),
            unsafe_passthrough_params: params.except(:private_token)
          ).task

          unauthorized_with_origin_header! if task.feature_disabled?

          service = CloudConnector::AvailableServices.find_by_name(task.feature_name)

          unless current_user.allowed_to_use?(:code_suggestions,
            service_name: task.feature_name,
            licensed_feature: task.licensed_feature
          )
            unauthorized_with_origin_header!
          end

          token = service.access_token(current_user)
          unauthorized_with_origin_header! if token.nil?

          body = task.body
          file_too_large_with_origin_header! if body.size > MAX_BODY_SIZE

          # we add expanded_ai_logging to header only if current user is internal user,
          Gitlab::AiGateway.push_feature_flag(:expanded_ai_logging, current_user)

          workhorse_headers =
            Gitlab::Workhorse.send_url(
              task.endpoint,
              body: body,
              headers: ai_gateway_headers(headers, service),
              method: "POST",
              timeouts: { read: 55 }
            )

          header(*workhorse_headers)

          status :ok
          body ''
        end
      end

      resources :direct_access do
        desc 'Get connection details to access AI gateway directly to generate code suggestions' do
          success code: 201
          failure [
            { code: 401, message: 'Unauthorized' },
            { code: 404, message: 'Not found' },
            { code: 429, message: 'Too many requests' }
          ]
        end

        params do
          optional :project_path, type: String, desc: 'The path of the project',
            documentation: { example: 'namespace/project' }
        end
        post do
          forbidden!('Direct connections are disabled') if forbid_direct_access?

          check_rate_limit!(:code_suggestions_direct_access, scope: current_user) do
            Gitlab::InternalEvents.track_event(
              'code_suggestions_direct_access_rate_limit_exceeded',
              user: current_user
            )

            render_api_error!({ error: _('This endpoint has been requested too many times. Try again later.') }, 429)
          end

          token = Gitlab::Llm::AiGateway::CodeSuggestionsClient.new(current_user).direct_access_token
          service_unavailable!(token[:message]) if token[:status] == :error

          unauthorized! if completion_model_details.feature_disabled?

          details_hash = completion_model_details.current_model

          access = {
            base_url: ::Gitlab::AiGateway.url,
            # for development purposes we just return instance JWT, this should not be used in production
            # until we generate a short-term token for user
            # https://gitlab.com/gitlab-org/modelops/applied-ml/code-suggestions/ai-assist/-/issues/429
            token: token[:token],
            expires_at: token[:expires_at],
            headers: ai_gateway_public_headers(completion_model_details.feature_name)
          }.tap do |a|
            a[:model_details] = details_hash unless details_hash.blank?
          end

          present access, with: Grape::Presenters::Presenter
        end
      end

      resources :enabled do
        desc 'Code suggestions enabled for a project' do
          success code: 200
          failure [
            { code: 401, message: 'Unauthorized' },
            { code: 403, message: '403 Code Suggestions Disabled' },
            { code: 404, message: 'Not found' }
          ]
        end
        params do
          requires :project_path, type: String, desc: 'The path of the project',
            documentation: { example: 'namespace/project' }
        end

        post do
          path = declared_params[:project_path]

          not_found! if path.empty?

          projects = ::ProjectsFinder.new(params: { full_paths: [path] }, current_user: current_user).execute

          not_found! if projects.none?

          forbidden! unless projects.first.project_setting.duo_features_enabled?

          status :ok
        end
      end

      resources :connection_details do
        desc 'Get details of the GitLab instance the user is connected to' do
          success code: 201
          failure [
            { code: 401, message: 'Unauthorized' },
            { code: 404, message: 'Not found' },
            { code: 429, message: 'Too many requests' }
          ]
        end

        post do
          unauthorized! if completion_model_details.feature_disabled?

          check_rate_limit!(:code_suggestions_connection_details, scope: current_user) do
            Gitlab::InternalEvents.track_event(
              'code_suggestions_connection_details_rate_limit_exceeded',
              user: current_user
            )

            render_api_error!({ error: _('This endpoint has been requested too many times. Try again later.') }, 429)
          end

          aigw_headers = Gitlab::AiGateway.public_headers(
            user: current_user,
            service_name: completion_model_details.feature_name
          )

          details = {
            instance_id: aigw_headers['x-gitlab-instance-id'],
            instance_version: Gitlab.version_info.to_s,
            realm: aigw_headers['x-gitlab-realm'],
            global_user_id: aigw_headers['x-gitlab-global-user-id'],
            host_name: aigw_headers['x-gitlab-host-name'],
            feature_enablement_type: aigw_headers['x-gitlab-feature-enablement-type'],
            saas_duo_pro_namespace_ids:
              saas_headers['X-Gitlab-Saas-Duo-Pro-Namespace-Ids'].to_s.split(',').compact.map(&:to_i)
          }

          present details, with: Grape::Presenters::Presenter
        end
      end
    end
  end
end
