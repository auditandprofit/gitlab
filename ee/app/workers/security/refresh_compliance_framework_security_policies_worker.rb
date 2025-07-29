# frozen_string_literal: true

module Security
  class RefreshComplianceFrameworkSecurityPoliciesWorker
    include Gitlab::EventStore::Subscriber

    data_consistency :sticky
    deduplicate :until_executing
    idempotent!

    feature_category :security_policy_management

    def handle_event(event)
      project = Project.find_by_id(event.data[:project_id])
      framework = ComplianceManagement::Framework.find_by_id(event.data[:compliance_framework_id])
      return unless project && framework

      policy_configuration_ids = project.all_security_orchestration_policy_configuration_ids
      return unless policy_configuration_ids.any?

      framework
        .security_orchestration_policy_configurations
        .with_security_policies.id_in(policy_configuration_ids)
        .find_each do |config|
          Security::ProcessScanResultPolicyWorker.perform_async(project.id, config.id)

          config.security_policies.undeleted.find_each do |security_policy|
            Security::SecurityOrchestrationPolicies::SyncPolicyEventService.new(
              project: project,
              security_policy: security_policy,
              event: event
            ).execute
          end
        end
    end
  end
end
