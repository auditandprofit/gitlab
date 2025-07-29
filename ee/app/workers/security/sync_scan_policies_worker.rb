# frozen_string_literal: true

module Security
  class SyncScanPoliciesWorker
    include ApplicationWorker
    include UpdateOrchestrationPolicyConfiguration

    data_consistency :always

    deduplicate :until_executed, if_deduplicated: :reschedule_once
    idempotent!

    feature_category :security_policy_management

    def perform(configuration_id, params = {})
      configuration = Security::OrchestrationPolicyConfiguration.find_by_id(configuration_id)

      return unless configuration

      force_resync = params['force_resync'] || false

      update_policy_configuration(configuration, force_resync)
    end
  end
end
