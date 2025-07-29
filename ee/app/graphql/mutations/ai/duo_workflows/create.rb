# frozen_string_literal: true

module Mutations
  module Ai
    module DuoWorkflows
      class Create < BaseMutation
        graphql_name 'AiDuoWorkflowCreate'

        # The actual auth check is performed by CreateWorkflowService based on the workflow definition
        authorize :developer_access

        def self.authorization_scopes
          super + [:ai_features]
        end

        argument :project_id, ::Types::GlobalIDType[::Project],
          required: false,
          description: "Global ID of the project the user is acting on."

        argument :namespace_id, ::Types::GlobalIDType[::Namespace],
          required: false,
          description: "Global ID of the namespace the user is acting on."

        argument :goal, GraphQL::Types::String,
          required: false,
          description: 'Goal of the workflow.'

        argument :agent_privileges, [GraphQL::Types::Int],
          required: false,
          description: 'Actions the agent is allowed to perform.'

        argument :pre_approved_agent_privileges, [GraphQL::Types::Int],
          required: false,
          description: 'Actions the agent can perform without asking for approval.'

        argument :workflow_definition, GraphQL::Types::String,
          required: false,
          description: 'Workflow type based on its capability.'

        argument :allow_agent_to_request_user, GraphQL::Types::Boolean,
          required: false,
          description: 'When enabled, Duo Agent Platform may stop to ask the user questions before proceeding.'

        argument :environment, Types::Ai::DuoWorkflows::WorkflowEnvironmentEnum,
          required: false,
          description: 'Environment for the workflow.'

        field :workflow, Types::Ai::DuoWorkflows::WorkflowType,
          null: true,
          description: 'Created workflow.'

        field :errors, [GraphQL::Types::String],
          null: false,
          description: 'Errors encountered during the creation process.'

        validates mutually_exclusive: [:project_id, :namespace_id]

        def resolve(**args)
          container = if args[:project_id]
                        authorized_find!(id: args[:project_id])
                      elsif args[:namespace_id]
                        authorized_find!(id: args[:namespace_id])
                      end

          workflow_params = {
            goal: args[:goal],
            agent_privileges: args[:agent_privileges],
            pre_approved_agent_privileges: args[:pre_approved_agent_privileges],
            workflow_definition: args[:workflow_definition],
            allow_agent_to_request_user: args[:allow_agent_to_request_user],
            environment: args[:environment]
          }.compact

          service = ::Ai::DuoWorkflows::CreateWorkflowService.new(
            container: container,
            current_user: current_user,
            params: workflow_params
          )

          result = service.execute

          raise_resource_not_available_error!(result.message) if result.error? && result.http_status == :forbidden
          return { errors: [result[:message]], workflow: nil } if result[:status] == :error

          {
            workflow: result[:workflow],
            errors: errors_on_object(result[:workflow])
          }
        end
      end
    end
  end
end
