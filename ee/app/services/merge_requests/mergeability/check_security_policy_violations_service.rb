# frozen_string_literal: true

module MergeRequests
  module Mergeability
    class CheckSecurityPolicyViolationsService < CheckBaseService
      identifier :security_policy_violations
      description 'Checks whether the security policies are satisfied'

      def execute
        if !merge_request.project.licensed_feature_available?(:security_orchestration_policies) ||
            merge_request.scan_result_policy_reads_through_approval_rules.none?
          return inactive
        end

        return checking if merge_request.running_scan_result_policy_violations.any?

        # When the MR is approved, it is considered to 'override' the violations
        if merge_request.failed_scan_result_policy_violations.any? && !merge_request.approved?
          failure
        else
          success
        end
      end

      def skip?
        params[:skip_security_policy_check].present?
      end

      def cacheable?
        false
      end
    end
  end
end
