# frozen_string_literal: true

module Security
  module ScanResultPolicies
    module PolicyViolationCommentGenerator
      private

      def generate_policy_bot_comment(merge_request)
        return unless violations_populated?(merge_request)
        return if bot_message_disabled?(merge_request)

        Security::GeneratePolicyViolationCommentWorker.perform_async(merge_request.id)
      end

      def violations_populated?(merge_request)
        !merge_request.scan_result_policy_violations.without_violation_data.exists?
      end

      # To reduce the noise on the merge request, policies can opt out of the bot comment.
      # If any violated policy has the bot comment enabled, it will be generated.
      # If there is an existing comment, it will always be updated even if the violated policies opt out.
      def bot_message_disabled?(merge_request)
        project = merge_request.project

        return true if project.archived?
        # Ensure to always trigger the worker to update the comment if it's already present on the merge request.
        # For example:
        #   - Previously, Policy A with bot comment enabled had a violation which generated a comment.
        #   - Now, only Policy B with bot comment disabled has a violation.
        #   - We need to trigger the worker to update the comment since it's outdated.
        return false if merge_request.policy_bot_comment.present?

        applicable_rules_policy_ids = merge_request.approval_rules.report_approver
                                           .applicable_to_branch(merge_request.target_branch)
                                           .filter_map(&:scan_result_policy_id)
        violated_policy_ids = merge_request.scan_result_policy_violations.filter_map(&:scan_result_policy_id)
        # Only check `bot_message_disabled?` for policies that are both applicable to the branch and have violations
        policies_requiring_bot_message_check = (applicable_rules_policy_ids & violated_policy_ids)
        return false if policies_requiring_bot_message_check.blank?

        policies = project.scan_result_policy_reads.id_in(policies_requiring_bot_message_check)
        return false if policies.blank?

        policies.all?(&:bot_message_disabled?)
      end
    end
  end
end
