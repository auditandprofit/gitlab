# frozen_string_literal: true

module Types
  module SecurityOrchestration
    module OrchestrationPolicyType
      include Types::BaseInterface

      field :description, GraphQL::Types::String, null: false, description: 'Description of the policy.'
      field :edit_path, GraphQL::Types::String, null: false, description: 'URL of policy edit page.'
      field :enabled, GraphQL::Types::Boolean, null: false, description: 'Indicates whether the policy is enabled.'
      field :name, GraphQL::Types::String, null: false, description: 'Name of the policy.'
      field :updated_at, Types::TimeType, null: false, description: 'Timestamp of when the policy YAML was last updated.'
      field :yaml, GraphQL::Types::String, null: false, description: 'YAML definition of the policy.'
      field :policy_scope, ::Types::SecurityOrchestration::PolicyScopeType, null: true, description: 'Scope of the policy.'
      field :csp, ::GraphQL::Types::Boolean,
        null: false,
        description: 'Indicates whether the policy comes from a centralized security policy group.',
        experiment: { milestone: '18.1' }
    end
  end
end
