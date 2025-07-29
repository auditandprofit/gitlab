# frozen_string_literal: true

module Security
  class ProcessScanResultPolicyWorker
    include ApplicationWorker

    idempotent!
    deduplicate :until_executed, if_deduplicated: :reschedule_once, including_scheduled: true

    data_consistency :always
    sidekiq_options retry: true
    feature_category :security_policy_management

    concurrency_limit -> { 200 }

    def perform(project_id, configuration_id)
      # This worker is now a no-op after removing the use_approval_policy_rules_for_approval_rules feature flag.
      # All functionality has been moved to the read model based approach.
    end
  end
end
