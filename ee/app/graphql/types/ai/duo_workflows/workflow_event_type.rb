# frozen_string_literal: true

module Types
  module Ai
    module DuoWorkflows
      class WorkflowEventType < Types::BaseObject
        graphql_name 'DuoWorkflowEvent'
        description "Events that describe the history and progress of a GitLab Duo Agent Platform session"
        present_using ::Ai::DuoWorkflows::WorkflowCheckpointEventPresenter
        authorize :read_duo_workflow_event

        def self.authorization_scopes
          [:api, :read_api, :ai_features, :ai_workflows]
        end

        field :checkpoint, Types::JsonStringType,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          description: 'Checkpoint of the event.'

        field :metadata, Types::JsonStringType,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          description: 'Metadata associated with the event.'

        field :workflow_status, Types::Ai::DuoWorkflows::WorkflowStatusEnum,
          description: 'Status of the session.'

        field :execution_status, GraphQL::Types::String,
          null: false, description: "Granular status of the session's execution.",
          experiment: { milestone: '17.10' }

        field :timestamp, Types::TimeType,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          description: 'Time of the event.'

        field :parent_timestamp, Types::TimeType,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          description: 'Time of the parent event.'

        field :errors, [GraphQL::Types::String],
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          null: true, description: 'Message errors.'

        # rubocop:disable GraphQL/ExtractType -- no need to extract two fields into a separate field
        field :workflow_goal, GraphQL::Types::String,
          description: 'Goal of the session.'

        field :workflow_definition, GraphQL::Types::String,
          description: 'GitLab Duo Agent Platform flow type based on its capabilities.'
        # rubocop:enable GraphQL/ExtractType -- we want to keep this way for backwards compatibility
      end
    end
  end
end
