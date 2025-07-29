# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class UnblockFailOpenApprovalRulesService
      include Gitlab::Utils::StrongMemoize

      REPORT_TYPES = %i[scan_finding license_scanning].freeze

      def initialize(merge_request:, report_types: REPORT_TYPES)
        @merge_request = merge_request
        @report_types = report_types

        raise(ArgumentError, "unrecognized report_type") if (report_types - REPORT_TYPES).any?
      end

      def execute
        return if fail_open_approval_rules.empty?

        ApplicationRecord.transaction do
          ApprovalMergeRequestRule.remove_required_approved(fail_open_approval_rules.map(&:id))

          merge_request
            .scan_result_policy_violations
            .for_approval_rules(fail_open_approval_rules)
            .delete_all
        end
      end

      private

      attr_reader :merge_request, :report_types

      def fail_open_approval_rules
        approval_rules.select { |rule| rule.scan_result_policy_read&.fail_open? }
      end
      strong_memoize_attr :fail_open_approval_rules

      def approval_rules
        merge_request.approval_rules.by_report_types(report_types).including_scan_result_policy_read
      end
    end
  end
end
