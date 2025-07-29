# frozen_string_literal: true

module EE
  module Types
    module SubscriptionType
      extend ActiveSupport::Concern

      prepended do
        def self.authorization_scopes
          [:api, :read_api, :ai_features]
        end

        field :ai_completion_response,
          subscription: ::Subscriptions::AiCompletionResponse, null: true,
          scopes: [:api, :read_api, :ai_features],
          description: 'Triggered when a response from AI integration is received.',
          experiment: { milestone: '15.11' }

        field :issuable_weight_updated,
          subscription: Subscriptions::IssuableUpdated, null: true,
          description: 'Triggered when the weight of an issuable is updated.'

        field :issuable_iteration_updated,
          subscription: Subscriptions::IssuableUpdated, null: true,
          description: 'Triggered when the iteration of an issuable is updated.'

        field :issuable_health_status_updated,
          subscription: Subscriptions::IssuableUpdated, null: true,
          description: 'Triggered when the health status of an issuable is updated.'

        field :issuable_epic_updated,
          subscription: Subscriptions::IssuableUpdated, null: true,
          description: 'Triggered when the epic of an issuable is updated.'

        field :workflow_events_updated,
          subscription: ::Subscriptions::Ai::DuoWorkflows::WorkflowEventsUpdated, null: true,
          description: 'Triggered when the checkpoints/events of a workflow is updated.'

        field :security_policy_project_created,
          subscription: Subscriptions::Security::PolicyProjectCreated, null: true,
          description: 'Triggered when the security policy project is created for a specific group or project.',
          experiment: { milestone: '17.3' }
      end
    end
  end
end
