# frozen_string_literal: true

module Namespaces
  class NamespaceSettingChangesAuditor < ::AuditEvents::BaseChangesAuditor
    EVENT_NAME_PER_COLUMN = {
      duo_features_enabled: 'duo_features_enabled_updated',
      experiment_features_enabled: 'experiment_features_enabled_updated',
      prevent_forking_outside_group: 'prevent_forking_outside_group_updated',
      allow_mfa_for_subgroups: 'allow_mfa_for_subgroups_updated',
      default_branch_name: 'default_branch_name_updated',
      resource_access_token_creation_allowed: 'resource_access_token_creation_allowed_updated',
      new_user_signups_cap: 'new_user_signups_cap_updated',
      show_diff_preview_in_email: 'show_diff_preview_in_email_updated',
      enabled_git_access_protocol: 'enabled_git_access_protocol_updated',
      runner_registration_enabled: 'runner_registration_enabled_updated',
      allow_runner_registration_token: 'allow_runner_registration_token_updated',
      emails_enabled: 'emails_enabled_updated',
      service_access_tokens_expiration_enforced: 'service_access_tokens_expiration_enforced_updated',
      enforce_ssh_certificates: 'enforce_ssh_certificates_updated',
      disable_personal_access_tokens: 'disable_personal_access_tokens_updated',
      remove_dormant_members: 'remove_dormant_members_updated',
      remove_dormant_members_period: 'remove_dormant_members_period_updated',
      prevent_sharing_groups_outside_hierarchy: 'prevent_sharing_groups_outside_hierarchy_updated',
      seat_control: 'seat_control_updated'
    }.freeze

    def initialize(current_user, namespace_setting, group)
      @group = group

      super(current_user, namespace_setting)
    end

    def execute
      return if model.blank?

      EVENT_NAME_PER_COLUMN.each do |column, event_name|
        audit_changes(column, entity: @group, model: model, event_type: event_name)
      end
    end

    private

    def attributes_from_auditable_model(column)
      {
        from: model.previous_changes[column].first,
        to: model.previous_changes[column].last,
        target_details: @group.full_path
      }
    end
  end
end
