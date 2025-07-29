# frozen_string_literal: true

#
# This resolver is a WIP and part of ongoing work for the Security Dashboard Project (https://gitlab.com/groups/gitlab-org/-/epics/16517)
#
module Resolvers
  module Security
    class SecurityMetricsResolver < BaseResolver
      include Gitlab::Utils::StrongMemoize
      include Gitlab::Graphql::Authorize::AuthorizeResource

      type Types::Security::SecurityMetricsType, null: true
      authorize :read_security_resource

      argument :project_id, [GraphQL::Types::ID],
        required: false,
        description: 'Filter by project IDs.'

      argument :severity, [Types::VulnerabilitySeverityEnum],
        required: false,
        description: 'Filter by vulnerability severity levels.'

      argument :scanner, [GraphQL::Types::String],
        required: false,
        description: 'Filter by scanner names.'

      def resolve(**_args)
        authorize!(object)

        return unless Feature.enabled?(:group_security_dashboard_new, object)

        object
      end
    end
  end
end
