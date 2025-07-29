# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class SyncProjectApprovalPolicyRulesService
      include Gitlab::Utils::StrongMemoize

      def initialize(project:, security_policy:)
        @project = project
        @security_policy = security_policy
      end

      def create_rules(approval_policy_rules = security_policy.approval_policy_rules.undeleted)
        create_approval_rules(approval_policy_rules)
        sync_merge_request_rules
      end

      def update_rules(approval_policy_rules = security_policy.approval_policy_rules.undeleted)
        update_approval_rules(approval_policy_rules)
        sync_merge_request_rules
      end

      def delete_rules(approval_policy_rules = security_policy.approval_policy_rules)
        delete_approval_rules(approval_policy_rules)
        sync_merge_request_rules
      end

      def sync_policy_diff(policy_diff)
        created_rules, deleted_rules = find_changed_rules(policy_diff)
        security_policy.update_project_approval_policy_rule_links(project, created_rules, deleted_rules)

        # When a security policy's approval actions are modified (added or removed),
        # we perform a complete refresh of the associated rules
        # because we don't maintain direct references to the policy YAML actions.
        if policy_diff.needs_complete_rules_refresh?
          rules = security_policy.approval_policy_rules.undeleted
          delete_approval_rules(rules)
          create_approval_rules(rules)
        else
          delete_approval_rules(deleted_rules)
          create_approval_rules(created_rules)
          update_approval_rules(security_policy.approval_policy_rules.undeleted) if policy_diff.needs_rules_refresh?
        end

        sync_merge_request_rules
      end

      def protected_branch_ids(approval_policy_rule)
        service = Security::SecurityOrchestrationPolicies::PolicyBranchesService.new(project: project)
        applicable_branches = service.scan_result_branches([approval_policy_rule.content.deep_symbolize_keys])
        protected_branches = project.all_protected_branches.select do |protected_branch|
          applicable_branches.any? { |branch| protected_branch.matches?(branch) }
        end

        # rubocop:disable Database/AvoidUsingPluckWithoutLimit, CodeReuse/ActiveRecord -- protected branches will be limited
        protected_branches.pluck(:id)
        # rubocop:enable Database/AvoidUsingPluckWithoutLimit, CodeReuse/ActiveRecord
      end

      private

      attr_reader :project, :security_policy

      def find_policy_rules(policy_rule_ids)
        security_policy.approval_policy_rules.id_in(policy_rule_ids)
      end

      def find_changed_rules(policy_diff)
        created_rules = find_policy_rules(policy_diff.rules_diff.created.map(&:id))
        deleted_rules = find_policy_rules(policy_diff.rules_diff.deleted.map(&:id))

        [created_rules, deleted_rules]
      end

      def sync_merge_request_rules
        Security::SecurityOrchestrationPolicies::SyncMergeRequestsService.new(
          project: project, security_policy: security_policy
        ).execute
      end

      def delete_approval_rules(approval_policy_rules)
        Security::ScanResultPolicies::ApprovalRules::DeleteService.new(
          project: project,
          security_policy: security_policy,
          approval_policy_rules: approval_policy_rules
        ).execute
      end

      def update_approval_rules(approval_policy_rules)
        Security::ScanResultPolicies::ApprovalRules::UpdateService.new(
          project: project,
          security_policy: security_policy,
          approval_policy_rules: approval_policy_rules,
          author: author
        ).execute
      end

      def create_approval_rules(approval_policy_rules)
        Security::ScanResultPolicies::ApprovalRules::CreateService.new(
          project: project,
          security_policy: security_policy,
          approval_policy_rules: approval_policy_rules,
          author: author
        ).execute
      end

      def author
        security_policy.security_orchestration_policy_configuration.policy_last_updated_by
      end
      strong_memoize_attr :author
    end
  end
end
