# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class PolicyRuleEvaluationService
      include Gitlab::Utils::StrongMemoize
      include Gitlab::InternalEventsTracking
      include ::Security::ScanResultPolicies::PolicyViolationCommentGenerator
      include ::Security::ScanResultPolicies::VulnerabilityStatesHelper

      def initialize(merge_request)
        @merge_request = merge_request
        @passed_rules = Set.new
        @failed_rules = Set.new
      end

      def save
        merge_request.reset_required_approvals(failed_rules) if failed_rules.any?
        ApprovalMergeRequestRule.remove_required_approved(passed_rules) if passed_rules.any?

        violations.execute
        generate_policy_bot_comment(merge_request)
      end

      def pass!(approval_rule)
        passed_rules.add(approval_rule)
        return unless approval_rule.scan_result_policy_read

        violations.remove_violation(approval_rule.scan_result_policy_read)
      end

      def fail!(approval_rule, data: nil, context: nil)
        failed_rules.add(approval_rule)
        return unless approval_rule.scan_result_policy_read

        violations.add_violation(
          approval_rule.scan_result_policy_read, approval_rule.report_type, data, context: context
        )
      end

      def error!(approval_rule, error, **extra_data)
        if excluded?(approval_rule)
          pass!(approval_rule)
          return
        end

        process_default_behaviour(approval_rule)

        return unless approval_rule.scan_result_policy_read

        violations.add_error(approval_rule.scan_result_policy_read, error, **extra_data)
      end

      def skip!(approval_rule)
        process_default_behaviour(approval_rule)
        violations.skip(approval_rule.scan_result_policy_read) if approval_rule.scan_result_policy_read
      end

      private

      attr_reader :merge_request, :passed_rules, :failed_rules

      delegate :project, to: :merge_request

      def excluded?(rule)
        return true unless rule_applies_to_target_branch?(rule)
        return false unless rule.scan_result_policy_read&.unblock_rules_using_execution_policies?
        return false unless rule_excludable?(rule)

        if execution_policy_scan_enforced?(rule)
          track_unblock_event(rule)
          return true
        end

        false
      end

      def rule_applies_to_target_branch?(rule)
        if ::Feature.disabled?(
          :merge_request_approval_policies_inapplicable_rule_evaluation, merge_request.project)
          return true
        end

        rule.applicable_to_branch?(merge_request.target_branch)
      end

      def process_default_behaviour(rule)
        if rule.scan_result_policy_read&.fail_open?
          passed_rules.add(rule)
        else
          failed_rules.add(rule)
        end
      end

      def violations
        @violations ||= Security::SecurityOrchestrationPolicies::UpdateViolationsService.new(merge_request)
      end

      def track_unblock_event(rule)
        track_internal_event(
          'unblock_approval_rule_using_scan_execution_policy',
          project: project,
          additional_properties: {
            label: rule.scanners.join(',')
          }
        )
      end

      # Refactor the methods below with PORO classes: https://gitlab.com/gitlab-org/gitlab/-/issues/504305
      def execution_policy_scan_enforced?(rule)
        scanners = extract_scanners(rule)
        return false if scanners.blank?

        enforced_scans = Set.new(active_scan_execution_policy_scans + pipeline_execution_policy_scans(rule))
        scanners.all? { |scanner| enforced_scans.include?(scanner) }
      end

      def pipeline_execution_policy_scans(rule)
        # NOTE: Only take configurations for the rule's configuration and its ancestors,
        # so that an approval rule defined by group cannot get unblocked by a project-level policy.
        configuration_ids = rule.security_orchestration_policy_configuration&.self_and_ancestor_configuration_ids
        return [] if configuration_ids.blank?

        project.security_policies.type_pipeline_execution_policy
               .for_policy_configuration(configuration_ids)
               .flat_map(&:enforced_scans).compact.uniq
      end

      # Only allow rules to be excludable if they only target newly detected states. We cannot reliably exclude
      # previously detected states based on active SEP, as they may not had been enforced on the target branch.
      def rule_excludable?(rule)
        case rule.report_type
        when 'scan_finding'
          only_newly_detected?(rule)
        when 'license_scanning'
          rule.scan_result_policy_read&.only_newly_detected_licenses? || false
        else
          false
        end
      end

      def extract_scanners(rule)
        case rule.report_type
        when 'scan_finding'
          rule.scanners.presence || Security::ScanExecutionPolicy::PIPELINE_SCAN_TYPES
        when 'license_scanning'
          %w[dependency_scanning]
        end
      end

      def active_scan_execution_policy_scans
        active_scans_for_ref = project.all_security_orchestration_policy_configurations
        .flat_map do |configuration|
          configuration.active_pipeline_policies_for_project(merge_request.source_branch_ref, project)
                       .flat_map { |policy| policy[:actions] }
        end
        # rubocop:disable Database/AvoidUsingPluckWithoutLimit, CodeReuse/ActiveRecord -- used on hashes
        active_scans_for_ref.pluck(:scan)
        # rubocop:enable Database/AvoidUsingPluckWithoutLimit, CodeReuse/ActiveRecord
      end
      strong_memoize_attr :active_scan_execution_policy_scans
    end
  end
end
