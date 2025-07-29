# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class SyncAnyMergeRequestRulesService
      include Gitlab::Utils::StrongMemoize
      include ::Security::ScanResultPolicies::PolicyViolationCommentGenerator
      include ::Security::ScanResultPolicies::PolicyLogger

      REPORT_TYPE = :any_merge_request

      def initialize(merge_request)
        @merge_request = merge_request
        @violations = Security::SecurityOrchestrationPolicies::UpdateViolationsService.new(merge_request)
        @violations_by_policy = {}
      end

      def execute
        return if merge_request.merged?

        sync_required_approvals
      end

      private

      attr_reader :merge_request, :violations, :violations_by_policy

      delegate :project, to: :merge_request, private: true

      def sync_required_approvals
        related_policies = merge_request.project.scan_result_policy_reads.targeting_commits
                                        .including_approval_merge_request_rules
        return if related_policies.empty?

        violated_policies, unviolated_policies = evaluate_policy_violations(related_policies)

        log_message('Evaluating any_merge_request rules from approval policies')
        violated_rules, unviolated_rules = rules_for_violated_policies(violated_policies)
        violated_rules, unviolated_rules = update_required_approvals(violated_rules, unviolated_rules)

        log_violated_rules(violated_rules)
        violated_policies -= unviolated_rules.map(&:scan_result_policy_read)
        violations.add(
          violated_policies,
          unviolated_policies + unviolated_rules.map(&:scan_result_policy_read)
        )
        save_violation_data(violated_policies)
        violations.execute
        generate_policy_bot_comment(merge_request)
      end

      def evaluate_policy_violations(scan_result_policy_reads)
        unsigned_commits = merge_request.commits(load_from_gitaly: true)
                                         .select { |commit| !commit.has_signature? }.map(&:short_id)
        violated, unviolated = scan_result_policy_reads.partition do |scan_result_policy_read|
          targets_any_commits = scan_result_policy_read.commits_any?
          next false unless targets_any_commits || (scan_result_policy_read.commits_unsigned? && unsigned_commits.any?)

          policy_affected_by_target_branch?(scan_result_policy_read).tap do |violated|
            next unless violated

            violations_by_policy[scan_result_policy_read.id] =
              targets_any_commits ? true : Security::ScanResultPolicyViolation.trim_violations(unsigned_commits)
          end
        end
        [violated, unviolated]
      end

      def active_policies
        configurations = project.all_security_orchestration_policy_configurations
        return [] if configurations.empty?

        configurations
          .flat_map(&:active_scan_result_policies)
          .select { |policy| policy_applicable?(policy) }
      end
      strong_memoize_attr :active_policies

      def policy_scope_checker
        ::Security::SecurityOrchestrationPolicies::PolicyScopeChecker.new(project: project)
      end
      strong_memoize_attr :policy_scope_checker

      def policy_applicable?(policy)
        policy_scope_checker.policy_applicable?(policy)
      end

      def policy_branch_service
        ::Security::SecurityOrchestrationPolicies::PolicyBranchesService.new(project: project)
      end
      strong_memoize_attr :policy_branch_service

      def policy_affected_by_target_branch?(policy)
        rule = active_policies.dig(policy.orchestration_policy_idx, :rules, policy.rule_idx)
        return true if rule.blank?

        return false if branch_excepted?(rule[:branch_exceptions])

        # If there are approval rules, they are already filtered for target branch
        return true if policy.approval_merge_request_rules.any?

        affected_branches = policy_branch_service.scan_result_branches([rule])
        affected_branches.include? merge_request.target_branch
      end

      def branch_excepted?(exceptions)
        exceptions&.any? do |exception|
          case exception
          when String then merge_request.target_branch == exception
          when Hash then merge_request.target_branch == exception[:name] && exception[:full_path] == project.full_path
          end
        end
      end

      def any_merge_request_rules
        merge_request.approval_rules.any_merge_request
      end
      strong_memoize_attr :any_merge_request_rules

      def rules_for_violated_policies(violated_policies)
        approval_rules_for_target_branch = any_merge_request_rules.applicable_to_branch(merge_request.target_branch)

        violated_rules = approval_rules_for_policies(approval_rules_for_target_branch, violated_policies)
        unviolated_rules = any_merge_request_rules - violated_rules

        [violated_rules, unviolated_rules]
      end

      def update_required_approvals(violated_rules, unviolated_rules)
        updated_violated_rules = merge_request.reset_required_approvals(violated_rules)
        ApprovalMergeRequestRule.remove_required_approved(unviolated_rules) if unviolated_rules.any?
        [updated_violated_rules, unviolated_rules]
      end

      def approval_rules_for_policies(approval_rules, policies)
        approval_rules.select { |rule| policies.map(&:id).include? rule.scan_result_policy_id }
      end

      def log_violated_rules(rules)
        return unless rules.any?

        rules.each do |approval_rule|
          log_message('Updating MR approval rule',
            reason: 'any_merge_request rule violated',
            approval_rule_id: approval_rule.id,
            approval_rule_name: approval_rule.name
          )
        end
      end

      def log_message(message, **attributes)
        log_policy_evaluation('update_approvals', message,
          project: project, merge_request_id: merge_request.id,
          merge_request_iid: merge_request.iid, **attributes)
      end

      def save_violation_data(violated_policies)
        violated_policies.each do |policy|
          violations.add_violation(policy, REPORT_TYPE, { commits: violations_by_policy[policy.id] })
        end
      end
    end
  end
end
