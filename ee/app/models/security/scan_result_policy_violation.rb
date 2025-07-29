# frozen_string_literal: true

module Security
  class ScanResultPolicyViolation < ApplicationRecord
    include EachBatch

    belongs_to :project, inverse_of: :scan_result_policy_violations
    belongs_to :scan_result_policy_read,
      class_name: 'Security::ScanResultPolicyRead',
      foreign_key: 'scan_result_policy_id',
      inverse_of: :violations

    belongs_to :merge_request, inverse_of: :scan_result_policy_violations
    belongs_to :approval_policy_rule, class_name: 'Security::ApprovalPolicyRule', inverse_of: :violations
    has_one :security_policy, class_name: 'Security::Policy', through: :approval_policy_rule

    validates :scan_result_policy_id, uniqueness: { scope: %i[merge_request_id] }
    validates :violation_data, json_schema: { filename: 'scan_result_policy_violation_data' }, allow_blank: true

    scope :running, -> { where(status: :running) }

    enum :status, {
      running: 0,
      failed: 1,
      warn: 2,
      skipped: 3
    }

    scope :including_scan_result_policy_reads, -> { includes(:scan_result_policy_read) }
    scope :including_security_policies, -> { includes(:security_policy) }

    scope :for_approval_rules,
      ->(approval_rules) {
        where(scan_result_policy_id: approval_rules.pluck(:scan_result_policy_id))
      }

    scope :without_violation_data, -> { where(violation_data: nil) }
    scope :with_violation_data, -> { where.not(violation_data: nil) }

    ERRORS = {
      scan_removed: 'SCAN_REMOVED',
      target_pipeline_missing: 'TARGET_PIPELINE_MISSING',
      artifacts_missing: 'ARTIFACTS_MISSING',
      evaluation_skipped: 'EVALUATION_SKIPPED',
      pipeline_failed: 'PIPELINE_FAILED'
    }.freeze

    MAX_VIOLATIONS = 10

    def self.trim_violations(violations)
      Array.wrap(violations)[..MAX_VIOLATIONS]
    end
  end
end
