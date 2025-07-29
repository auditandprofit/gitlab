# frozen_string_literal: true

module Security
  class PolicySetting < ApplicationRecord
    self.table_name = 'security_policy_settings'

    validates :csp_namespace, top_level_group: true
    validates :organization, uniqueness: true

    validate :validate_csp_is_group

    # A group for managing Centralized Security Policies
    belongs_to :organization, class_name: 'Organizations::Organization'
    belongs_to :csp_namespace, class_name: 'Group', optional: true

    after_commit :trigger_security_policies_updates, if: :saved_change_to_csp_namespace_id?

    ignore_column :singleton, remove_with: '18.4', remove_after: '2025-08-21'

    def self.for_organization(organization)
      safe_find_or_create_by(organization: organization) # rubocop:disable Performance/ActiveRecordSubtransactionMethods -- only uses a subtransaction if creating a record, which should only happen once per organization
    end

    def csp_enabled?(group)
      return false if GitlabSubscriptions::SubscriptionHelper.gitlab_com_subscription?

      csp_namespace_id.present? && (
        ::Feature.enabled?(:security_policies_csp, group) ||
          ::Feature.enabled?(:security_policies_csp, group&.root_ancestor) ||
          ::Feature.enabled?(:security_policies_csp, :instance)
      )
    end

    private

    def validate_csp_is_group
      return if csp_namespace_id.blank?
      return if csp_namespace&.group_namespace?

      errors.add(:csp_namespace, 'must be a group')
    end

    def trigger_security_policies_updates
      old_configuration = Security::OrchestrationPolicyConfiguration
                            .find_by(namespace_id: csp_namespace_id_previously_was)

      # Recreate the configuration for the previous group to unlink it from all projects and link it to its hierarchy
      ::Security::RecreateOrchestrationConfigurationWorker.perform_async(old_configuration.id) if old_configuration

      new_configuration = csp_namespace&.security_orchestration_policy_configuration
      return unless new_configuration

      # Force resync of the policies for all projects for the new CSP configuration
      Security::SyncScanPoliciesWorker.perform_async(new_configuration.id, { 'force_resync' => true })
    end
  end
end
