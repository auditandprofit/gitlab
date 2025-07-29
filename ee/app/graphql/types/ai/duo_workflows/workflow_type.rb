# frozen_string_literal: true

module Types
  module Ai
    module DuoWorkflows
      class WorkflowType < Types::BaseObject
        graphql_name 'DuoWorkflow'
        description 'GitLab Duo Agent Platform session'
        present_using ::Ai::DuoWorkflows::WorkflowPresenter
        authorize :read_duo_workflow

        def self.authorization_scopes
          [:api, :read_api, :ai_features, :ai_workflows]
        end

        field :id, type: GraphQL::Types::ID,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          null: false, description: 'ID of the session.'

        # The user id will always be the current_user.id as
        # only workflow owners can read a workflow
        field :user_id, Types::GlobalIDType[User],
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          null: false, description: 'ID of the user.'

        field :project_id, Types::GlobalIDType[Project],
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          null: true, description: 'ID of the project.'

        field :project, Types::ProjectType,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          null: true, description: "Project that the session is in."

        field :namespace_id, Types::GlobalIDType[Namespace],
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          null: true, description: 'ID of the namespace.'

        field :namespace, Types::NamespaceType,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          null: true, description: "namespace that the session is in."

        field :human_status, GraphQL::Types::String,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          null: false, description: 'Human-readable status of the session.'

        field :created_at, Types::TimeType,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          null: false, description: 'Timestamp of when the session was created.'

        field :updated_at, Types::TimeType,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          null: false, description: 'Timestamp of when the session was last updated.'

        field :goal, GraphQL::Types::String,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          description: 'Goal of the session.'

        field :workflow_definition, GraphQL::Types::String,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          description: 'GitLab Duo Agent Platform flow type based on its capabilities.'

        field :environment, Types::Ai::DuoWorkflows::WorkflowEnvironmentEnum,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          description: 'Environment, like IDE or web.'

        field :agent_privileges_names, [GraphQL::Types::String],
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          description: 'Privileges granted to the agent during execution.'

        field :pre_approved_agent_privileges_names, [GraphQL::Types::String],
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          description: 'Privileges pre-approved for the agent during execution.'

        field :mcp_enabled, GraphQL::Types::Boolean,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          description: 'Has MCP been enabled for the namespace.'

        field :allow_agent_to_request_user, GraphQL::Types::Boolean,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          description: 'Allow the agent to request user input.'

        field :status, Types::Ai::DuoWorkflows::WorkflowStatusEnum,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          description: 'Status of the session.'

        field :status_name, GraphQL::Types::String,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          description: 'Status name of the session.'

        field :first_checkpoint, Types::Ai::DuoWorkflows::WorkflowEventType,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          description: "First checkpoint of the session."

        field :latest_checkpoint, Types::Ai::DuoWorkflows::WorkflowEventType,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          description: "Latest checkpoint of the session."

        field :archived, GraphQL::Types::Boolean, method: :archived?,
          description: 'Archived due to retention policy.'

        field :stalled, GraphQL::Types::Boolean, method: :stalled?,
          description: 'Workflow got created but has no checkpoints.'

        field :last_executor_logs_url, GraphQL::Types::String,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          description: "URL to the latest executor logs of the workflow."
      end
    end
  end
end
