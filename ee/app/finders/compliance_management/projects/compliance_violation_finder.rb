# frozen_string_literal: true

module ComplianceManagement
  module Projects
    class ComplianceViolationFinder
      include ::Gitlab::Utils::StrongMemoize

      LIMIT = 100

      def initialize(group, current_user)
        @group = group
        @current_user = current_user
      end

      def execute
        return model.none unless allowed?

        records_for_group
      end

      private

      attr_reader :group, :current_user

      def allowed?
        Ability.allowed?(current_user, :read_compliance_violations_report, group)
      end

      def model
        ::ComplianceManagement::Projects::ComplianceViolation
      end

      def records_for_group
        Gitlab::Pagination::Keyset::InOperatorOptimization::QueryBuilder.new(
          scope: base_scope,
          array_scope: group.self_and_descendant_ids,
          array_mapping_scope: model.method(:in_optimization_array_mapping_scope),
          finder_query: model.method(:in_optimization_finder_query)
        ).execute.limit(LIMIT)
      end

      def base_scope
        base_scope = model

        order_by_scope(base_scope)
      end

      def order_by_scope(base_scope)
        base_scope.order_by_created_at_and_id(:desc)
      end
    end
  end
end
