# frozen_string_literal: true

module Security
  class UnenforceablePolicyRulesNotificationWorker
    include ApplicationWorker

    idempotent!
    data_consistency :sticky
    feature_category :security_policy_management

    def perform(merge_request_id, params = {})
      merge_request = MergeRequest.find_by_id(merge_request_id)

      return unless merge_request

      project = merge_request.project
      return unless project.licensed_feature_available?(:security_orchestration_policies)

      return if merge_request.approval_rules.with_scan_result_policy_read.none? &&
        params['force_without_approval_rules'].blank?

      Security::UnenforceablePolicyRulesNotificationService.new(merge_request).execute
    end
  end
end
