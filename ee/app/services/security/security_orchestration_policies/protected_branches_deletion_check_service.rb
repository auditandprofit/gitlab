# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class ProtectedBranchesDeletionCheckService < BaseProjectService
      include Gitlab::Utils::StrongMemoize

      def execute(protected_branches)
        protected_branches.reject do |protected_branch|
          applicable_branches.none? do |branch|
            RefMatcher.new(branch).matching([protected_branch.name]).any?
          end
        end
      end

      private

      def applicable_branches
        PolicyBranchesService.new(project: project).scan_result_branches(rules).merge(blocked_branch_patterns)
      end
      strong_memoize_attr :applicable_branches

      def blocked_branch_patterns
        rules.filter_map { |rule| rule[:branches] }.flatten
      end

      def rules
        blocking_policies = applicable_scan_result_policies.select do |policy|
          policy.dig(:approval_settings, :block_branch_modification)
        end

        blocking_policies.pluck(:rules).flatten # rubocop: disable CodeReuse/ActiveRecord -- blocking_policies is not expected to be an ActiveRecord::Relation but an Array
      end
      strong_memoize_attr :rules

      def applicable_scan_result_policies
        policy_scope_checker = Security::SecurityOrchestrationPolicies::PolicyScopeChecker.new(project: project)

        project
          .all_security_orchestration_policy_configurations
          .flat_map(&:active_scan_result_policies)
          .select { |policy| policy_scope_checker.policy_applicable?(policy) }
      end
    end
  end
end
