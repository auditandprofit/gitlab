# frozen_string_literal: true

module API
  module Ai
    module DuoWorkflows
      class Workflows < ::API::Base
        include PaginationParams
        include APIGuard

        helpers ::API::Helpers::DuoWorkflowHelpers

        feature_category :duo_workflow

        before do
          authenticate!
          set_current_organization
        end

        helpers do
          def find_workflow!(id)
            workflow = ::Ai::DuoWorkflows::Workflow.for_user_with_id!(current_user.id, id)
            return workflow if current_user.can?(:read_duo_workflow, workflow)

            forbidden!
          end

          def authorize_feature_flag!
            disabled =
              case params[:workflow_definition]
              when 'chat'
                Feature.disabled?(:duo_agentic_chat, current_user)
              when nil
                Feature.disabled?(:duo_workflow, current_user) && Feature.disabled?(:duo_agentic_chat, current_user)
              else
                Feature.disabled?(:duo_workflow, current_user)
              end

            not_found! if disabled
          end

          def start_workflow_params(workflow_id)
            if Feature.enabled?(:duo_workflow_use_composite_identity, current_user)
              use_service_account = true
              oauth_token = composite_identity_token
            else
              use_service_account = false
              oauth_token = gitlab_oauth_token
            end

            {
              goal: params[:goal],
              workflow_definition: params[:workflow_definition],
              workflow_id: workflow_id,
              workflow_oauth_token: oauth_token.plaintext_token,
              workflow_service_token: duo_workflow_token[:token],
              use_service_account: use_service_account,
              source_branch: params[:source_branch],
              workflow_metadata: Gitlab::DuoWorkflow::Client.metadata(current_user).to_json
            }
          end

          def gitlab_oauth_token
            gitlab_oauth_token_result = ::Ai::DuoWorkflows::CreateOauthAccessTokenService.new(
              current_user: current_user,
              organization: ::Current.organization,
              workflow_definition: params[:workflow_definition]
            ).execute

            if gitlab_oauth_token_result[:status] == :error
              render_api_error!(gitlab_oauth_token_result[:message], gitlab_oauth_token_result[:http_status])
            end

            gitlab_oauth_token_result[:oauth_access_token]
          end

          def composite_identity_token
            composite_oauth_token_result = ::Ai::DuoWorkflows::CreateCompositeOauthAccessTokenService.new(
              current_user: current_user,
              organization: ::Current.organization
            ).execute

            composite_oauth_token_result[:oauth_access_token]
          end

          def duo_workflow_token
            duo_workflow_token_result = ::Ai::DuoWorkflow::DuoWorkflowService::Client.new(
              duo_workflow_service_url: Gitlab::DuoWorkflow::Client.url,
              current_user: current_user,
              secure: Gitlab::DuoWorkflow::Client.secure?
            ).generate_token
            bad_request!(duo_workflow_token_result[:message]) if duo_workflow_token_result[:status] == :error

            duo_workflow_token_result
          end

          def create_workflow_params
            declared_params(include_missing: false).except(:start_workflow, :source_branch)
          end

          params :workflow_params do
            optional :project_id, type: String, desc: 'The ID or path of the workflow project',
              documentation: { example: '1' }
            optional :namespace_id, type: String, desc: 'The ID or path of the workflow namespace',
              documentation: { example: '1' }
            optional :start_workflow, type: Boolean,
              desc: 'Optional parameter to start workflow in a CI pipeline.' \
                'This feature is currently in an experimental state.',
              documentation: { example: true }
            optional :goal, type: String, desc: 'Goal of the workflow',
              documentation: { example: 'Fix pipeline for merge request 1 in project 1' }
            optional :agent_privileges, type: [Integer], desc: 'The actions the agent is allowed to perform',
              documentation: { example: [1] }
            optional :pre_approved_agent_privileges, type: [Integer],
              desc: 'The actions the agent can perform without asking for approval',
              documentation: { example: [1] }
            optional :workflow_definition, type: String, desc: 'workflow type based on its capability',
              documentation: { example: 'software_developer' }
            optional :allow_agent_to_request_user, type: Boolean,
              desc: 'When this is enabled Duo Workflow may stop to ask the user questions before proceeding. ' \
                'When it is disabled Duo Workflow will always just run through the workflow without ever asking ' \
                'for user input. Defaults to true.',
              documentation: { example: true }
            optional :image, type: String, desc: 'Container image to use for running the workflow in CI pipeline.',
              documentation: { example: 'registry.gitlab.com/gitlab-org/duo-workflow/custom-image:latest' }
            optional :source_branch, type: String,
              desc: 'Source branch for the CI pipeline. Uses default branch when not specified.',
              documentation: { example: 'main' }
            optional :environment, type: String,
              values: ::Ai::DuoWorkflows::Workflow.environments.keys.map(&:to_s),
              desc: 'Environment for the workflow.',
              documentation: { example: 'web' }
            exactly_one_of :project_id, :namespace_id
          end
        end

        namespace :ai do
          namespace :duo_workflows do
            resources :direct_access do
              desc 'Connection details for accessing Duo Workflow Service directly' do
                detail 'This feature is experimental.'
                success code: 201
                failure [
                  { code: 401, message: 'Unauthorized' },
                  { code: 404, message: 'Not found' },
                  { code: 429, message: 'Too many requests' }
                ]
              end

              params do
                optional :workflow_definition, type: String, desc: 'workflow type based on its capability',
                  documentation: { example: 'software_developer' }
              end

              post do
                authorize_feature_flag!

                check_rate_limit!(:duo_workflow_direct_access, scope: current_user) do
                  render_api_error!(_('This endpoint has been requested too many times. Try again later.'), 429)
                end

                oauth_token = gitlab_oauth_token
                workflow_token = duo_workflow_token

                access = {
                  gitlab_rails: {
                    base_url: Gitlab.config.gitlab.url,
                    token: oauth_token.plaintext_token,
                    token_expires_at: oauth_token.expires_at
                  },
                  duo_workflow_service: {
                    base_url: Gitlab::DuoWorkflow::Client.url,
                    token: workflow_token[:token],
                    token_expires_at: workflow_token[:expires_at],
                    headers: Gitlab::DuoWorkflow::Client.headers(user: current_user),
                    secure: Gitlab::DuoWorkflow::Client.secure?
                  },
                  duo_workflow_executor: {
                    executor_binary_url: Gitlab::DuoWorkflow::Executor.executor_binary_url,
                    executor_binary_urls: Gitlab::DuoWorkflow::Executor.executor_binary_urls,
                    version: Gitlab::DuoWorkflow::Executor.version
                  },
                  workflow_metadata: Gitlab::DuoWorkflow::Client.metadata(current_user)
                }

                present access, with: Grape::Presenters::Presenter
              end
            end

            get :ws do
              forbidden! if Feature.disabled?(:duo_workflow_workhorse, current_user)

              authorize_feature_flag!

              require_gitlab_workhorse!

              status :ok
              content_type Gitlab::Workhorse::INTERNAL_API_CONTENT_TYPE

              push_feature_flags

              if Feature.enabled?(:agent_platform_model_selection) # rubocop:disable Gitlab/FeatureFlagWithoutActor -- This is an instance level feature flag
                duo_agent_platform_setting = ::Ai::FeatureSetting.find_or_initialize_by_feature(:duo_agent_platform)

                model_metadata_headers = Gitlab::Llm::AiGateway::AgentPlatform::ModelMetadata.new(
                  feature_setting: duo_agent_platform_setting
                ).execute || {}

                headers = Gitlab::DuoWorkflow::Client.cloud_connector_headers(user: current_user).merge(
                  'x-gitlab-oauth-token' => gitlab_oauth_token.plaintext_token,
                  'x-gitlab-unidirectional-streaming' => 'enabled'
                ).merge(model_metadata_headers)
              else
                headers = Gitlab::DuoWorkflow::Client.cloud_connector_headers(user: current_user).merge(
                  'x-gitlab-oauth-token' => gitlab_oauth_token.plaintext_token,
                  'x-gitlab-unidirectional-streaming' => 'enabled'
                )
              end

              {
                DuoWorkflow: {
                  Headers: headers,
                  ServiceURI: Gitlab::DuoWorkflow::Client.url,
                  Secure: Gitlab::DuoWorkflow::Client.secure?
                }
              }
            end

            namespace :workflows do
              desc 'creates workflow persistence' do
                detail 'This feature is experimental.'
                success code: 200
                failure [
                  { code: 400, message: 'Validation failed' },
                  { code: 401, message: 'Unauthorized' },
                  { code: 403, message: '403 Forbidden' },
                  { code: 404, message: 'Not found' }
                ]
              end
              params do
                use :workflow_params
              end
              post do
                container = if params[:project_id]
                              find_project!(params[:project_id])
                            elsif params[:namespace_id]
                              find_namespace!(params[:namespace_id])
                            end

                service = ::Ai::DuoWorkflows::CreateWorkflowService.new(
                  container: container, current_user: current_user, params: create_workflow_params)

                result = service.execute

                forbidden!(result.message) if result.error? && result.http_status == :forbidden
                bad_request!(result[:message]) if result[:status] == :error

                push_ai_gateway_headers

                if params[:start_workflow].present?
                  response = ::Ai::DuoWorkflows::StartWorkflowService.new(
                    workflow: result[:workflow],
                    params: start_workflow_params(result[:workflow].id)
                  ).execute

                  workload_id = response.payload && response.payload[:workload_id]
                  message = response.message
                end

                present result[:workflow], with: ::API::Entities::Ai::DuoWorkflows::Workflow,
                  workload: { id: workload_id, message: message }
              end

              desc 'Get all possible agent privileges and descriptions' do
                success code: 200
                failure [
                  { code: 401, message: 'Unauthorized' }
                ]
              end
              get 'agent_privileges' do
                present ::Ai::DuoWorkflows::Workflow::AgentPrivileges,
                  with: ::API::Entities::Ai::DuoWorkflows::Workflow::AgentPrivileges
              end
            end
          end
        end
      end
    end
  end
end
