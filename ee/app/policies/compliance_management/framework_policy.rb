# frozen_string_literal: true

module ComplianceManagement
  class FrameworkPolicy < BasePolicy
    delegate { @subject.namespace }

    condition(:custom_compliance_frameworks_enabled, scope: :subject) do
      @subject.namespace.feature_available?(:custom_compliance_frameworks)
    end

    condition(:group_level_compliance_pipeline_enabled, scope: :subject) do
      @subject.namespace.feature_available?(:evaluate_group_level_compliance_pipeline)
    end

    condition(:read_root_group) do
      @user.can?(:read_group, @subject.namespace.root_ancestor)
    end

    condition(:custom_roles_allowed, scope: :subject) do
      @subject.namespace.custom_roles_enabled?
    end

    desc "Custom role on group that enables managing compliance framework"
    condition(:role_enables_admin_compliance_framework) do
      ::Authz::CustomAbility.allowed?(@user, :admin_compliance_framework, @subject.namespace)
    end

    condition(:custom_ability_compliance_enabled) do
      custom_roles_allowed? && role_enables_admin_compliance_framework?
    end

    rule { can?(:owner_access) & custom_compliance_frameworks_enabled }.policy do
      enable :admin_compliance_framework
      enable :read_compliance_framework
      enable :read_compliance_adherence_report
    end

    rule { read_root_group & custom_compliance_frameworks_enabled }.policy do
      enable :read_compliance_framework
      enable :read_compliance_adherence_report
    end

    rule { can?(:owner_access) & group_level_compliance_pipeline_enabled }.policy do
      enable :admin_compliance_pipeline_configuration
    end

    rule { custom_ability_compliance_enabled & custom_compliance_frameworks_enabled }.policy do
      enable :admin_compliance_framework
      enable :read_compliance_framework
      enable :read_compliance_adherence_report
    end

    rule { custom_ability_compliance_enabled & group_level_compliance_pipeline_enabled }.policy do
      enable :admin_compliance_pipeline_configuration
    end
  end
end
