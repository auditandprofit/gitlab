# frozen_string_literal: true

module Types
  module Security
    class SecurityMetricsType < BaseObject # rubocop:disable Graphql/AuthorizeTypes -- Authorization is done in resolver layer
      graphql_name 'SecurityMetrics'
      description 'Represents security metrics'

      field :vulnerabilities_over_time, ::Types::Security::VulnerabilitiesOverTimeType.connection_type,
        null: true,
        description: 'Vulnerability metrics over time with filtering and grouping capabilities. ' \
          'This feature is currently under development and not yet available for general use',
        resolver: ::Resolvers::Security::VulnerabilitiesOverTimeResolver do
        argument :project_id, [GraphQL::Types::ID],
          required: false,
          description: 'Filter by project IDs.'

        argument :severity, [Types::VulnerabilitySeverityEnum],
          required: false,
          description: 'Filter by vulnerability severity levels.'

        argument :scanner, [GraphQL::Types::String],
          required: false,
          description: 'Filter by scanner types.'
      end
    end
  end
end
