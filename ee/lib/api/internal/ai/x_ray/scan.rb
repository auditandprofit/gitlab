# frozen_string_literal: true

# rubocop: disable Gitlab/AvoidGitlabInstanceChecks -- This feature is developed on extremely short notice,
# so I follow existing code patterns in code suggestions AddOn Flow.
module API
  module Internal
    module Ai
      module XRay
        class Scan < ::API::Base
          feature_category :code_suggestions

          helpers ::API::Ci::Helpers::Runner

          PURCHASE_NOT_FOUND_MESSAGE = "GitLab Duo Pro Add-On purchase can't be found"
          TOKEN_NOT_FOUND_MESSAGE = "GitLab Duo Pro Add-On access token missing. Please synchronise Add-On access token"

          before do
            authenticate_job!
            not_found! unless can?(current_user, :access_x_ray_on_instance)
            unauthorized!(PURCHASE_NOT_FOUND_MESSAGE) unless x_ray_available?
          end

          helpers do
            include ::Gitlab::Utils::StrongMemoize

            def x_ray_available?
              ::GitlabSubscriptions::AddOnPurchase.exists_for_unit_primitive?(:complete_code, current_namespace)
            end

            def code_suggestions_data
              CloudConnector::AvailableServices.find_by_name(:code_suggestions)
            end

            def model_gateway_headers(headers, code_suggestions_data)
              Gitlab::AiGateway.headers(user: current_job.user, service: code_suggestions_data,
                agent: headers["User-Agent"])
                .merge(saas_headers)
                .transform_values { |v| Array(v) }
            end

            def saas_headers
              return {} unless Gitlab.com?

              {
                'X-Gitlab-Saas-Namespace-Ids' => [current_namespace.id.to_s]
              }
            end

            def current_namespace
              current_job.namespace
            end
            strong_memoize_attr :current_namespace

            def ai_gateway_token
              code_suggestions_data.access_token(current_namespace)
            end
            strong_memoize_attr :ai_gateway_token
          end

          namespace 'internal' do
            resource :jobs do
              desc 'Provides information about X-Ray dependencies' do
                deprecated true
                detail "This endpoint is deprecated and will be removed in https://gitlab.com/gitlab-org/gitlab/-/issues/505471"
              end
              params do
                requires :id, type: Integer, desc: "Job's ID"
                requires :token, type: String, desc: "Job's authentication token"
              end
              post ':id/x_ray/scan' do
                check_rate_limit!(:code_suggestions_x_ray_scan, scope: current_job.project)

                workhorse_headers =
                  Gitlab::Workhorse.send_url(
                    File.join(::Gitlab::AiGateway.url, 'v1', 'x-ray', 'libraries'),
                    body: params.except(:token, :id).to_json,
                    headers: model_gateway_headers(headers, code_suggestions_data),
                    method: "POST"
                  )

                header(*workhorse_headers)
                status :ok
              end

              desc 'Updates list of dependencies for a programming language' do
                deprecated true
                detail "This endpoint is deprecated and will be removed in https://gitlab.com/gitlab-org/gitlab/-/issues/505471"
              end
              params do
                requires :id, type: Integer, desc: "Job's ID"
                requires :token, type: String, desc: "Job's authentication token"
                requires :language, type: String,
                  values: ::CodeSuggestions::ProgrammingLanguage::SUPPORTED_LANGUAGES.keys,
                  desc: 'The programming language of dependencies'
                requires :dependencies, type: Array[String],
                  coerce_with: ::API::Validations::Types::CommaSeparatedToArray.coerce,
                  desc: 'The list of dependencies'
              end
              post ':id/x_ray/dependencies' do
                check_rate_limit!(:code_suggestions_x_ray_dependencies, scope: current_job.project)

                service_response = ::CodeSuggestions::Xray::StoreDependenciesService.new(
                  current_job.project,
                  params[:language],
                  params[:dependencies]
                ).execute

                if service_response.success?
                  accepted!
                else
                  unprocessable_entity!(service_response.message)
                end
              end
            end
          end
        end
      end
    end
  end
end
# rubocop: enable Gitlab/AvoidGitlabInstanceChecks
