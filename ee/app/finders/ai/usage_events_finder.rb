# frozen_string_literal: true

module Ai
  class UsageEventsFinder
    include Gitlab::Utils::StrongMemoize

    attr_reader :resource, :current_user

    DEFAULT_LIMIT = 100

    def initialize(current_user, resource:)
      @current_user = current_user
      @resource = resource
    end

    def execute
      return ::Ai::UsageEvent.none unless Ability.allowed?(current_user, :read_enterprise_ai_analytics, resource)

      Gitlab::Pagination::Keyset::InOperatorOptimization::QueryBuilder.new(
        scope: in_operator_scope,
        array_scope: array_scope,
        array_mapping_scope: ::Ai::UsageEvent.method(:in_optimization_array_mapping_scope),
        finder_query: ::Ai::UsageEvent.method(:in_optimization_finder_query)
      ).execute.limit(DEFAULT_LIMIT)
    end

    private

    def array_scope
      resource.self_and_descendants(skope: Namespace).select(:id)
    end

    def in_operator_scope
      ::Ai::UsageEvent.exclude_future_events.sort_by_timestamp_id
    end
  end
end
