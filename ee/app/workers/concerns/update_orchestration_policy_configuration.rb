# frozen_string_literal: true

module UpdateOrchestrationPolicyConfiguration
  def update_policy_configuration(configuration, force_resync = false)
    configuration.invalidate_policy_yaml_cache

    unless configuration.policy_configuration_valid?
      configuration.delete_all_schedules
      Security::ScanResultPolicies::DeleteScanResultPolicyReadsWorker.perform_async(configuration.id)

      update_configuration_timestamp!(configuration)
      audit_invalid_policy_yaml(configuration) if collect_invalid_policy_yaml_event?(configuration)
      return
    end

    update_experiments_configuration!(configuration)

    unless force_resync || configuration.policies_changed?
      update_configuration_timestamp!(configuration)
      return
    end

    configuration.delete_all_schedules
    configuration.active_scan_execution_policies.each_with_index do |policy, policy_index|
      Security::SecurityOrchestrationPolicies::ProcessRuleService
        .new(policy_configuration: configuration, policy_index: policy_index, policy: policy)
        .execute
    end

    update_configuration_timestamp!(configuration)

    Security::PersistSecurityPoliciesWorker.perform_async(configuration.id, { 'force_resync' => force_resync })
  end

  private

  def update_experiments_configuration!(configuration)
    Security::SecurityOrchestrationPolicies::UpdateExperimentsService.new(
      policy_configuration: configuration
    ).execute
  end

  def audit_invalid_policy_yaml(configuration)
    Security::SecurityOrchestrationPolicies::CollectPolicyYamlInvalidatedAuditEventService.new(configuration).execute
  rescue StandardError => e
    Gitlab::ErrorTracking.track_exception(e,
      security_policy_management_project_id: configuration.security_policy_management_project.id,
      configuration_id: configuration.id
    )
  end

  def collect_invalid_policy_yaml_event?(configuration)
    configuration.first_configuration_for_the_management_project?
  end

  def update_configuration_timestamp!(configuration)
    configuration.update!(configured_at: Time.current)
  end
end
