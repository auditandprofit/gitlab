# frozen_string_literal: true

module Types
  module SecurityOrchestration
    class PolicyScopeType < BaseObject # rubocop:disable Graphql/AuthorizeTypes -- This is a read from policy YAML
      graphql_name 'PolicyScope'

      authorize []

      field :compliance_frameworks, ::Types::ComplianceManagement::ComplianceFrameworkType.connection_type,
        null: false,
        description: 'Compliance Frameworks linked to the policy.'

      field :including_projects, ::Types::ProjectType.connection_type,
        null: false,
        description: 'Projects to which the policy should be applied.'

      field :excluding_projects, ::Types::ProjectType.connection_type,
        null: false,
        description: 'Projects to which the policy should not be applied.'

      field :including_groups, ::Types::GroupType.connection_type, # rubocop:disable GraphQL/ExtractType -- following the convention in the GraphQL type
        null: false,
        description: 'Groups to which the policy should be applied.'

      field :excluding_groups, ::Types::GroupType.connection_type, # rubocop:disable GraphQL/ExtractType -- following the convention in the GraphQL type
        null: false,
        description: 'Groups to which the policy should not be applied.'
    end
  end
end
