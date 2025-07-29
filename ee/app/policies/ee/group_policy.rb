# frozen_string_literal: true

module EE
  module GroupPolicy
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    prepended do
      include ::Gitlab::Utils::StrongMemoize
      include RemoteDevelopment::GroupPolicy
      include Vulnerabilities::AdvancedVulnerabilityManagementPolicy

      condition(:ldap_synced, scope: :subject) { @subject.ldap_synced? }
      condition(:saml_group_links_exists, scope: :subject) do
        @subject.root_ancestor.saml_group_links_exists?
      end

      condition(:epics_available, scope: :subject) { @subject.feature_available?(:epics) }
      condition(:iterations_available, scope: :subject) { @subject.feature_available?(:iterations) }
      condition(:subepics_available, scope: :subject) { @subject.feature_available?(:subepics) }
      condition(:custom_fields_available, scope: :subject) { @subject.feature_available?(:custom_fields) }
      condition(:work_item_statuses_available, scope: :subject) { @subject.feature_available?(:work_item_status) }
      condition(:external_audit_events_available, scope: :subject) do
        @subject.feature_available?(:external_audit_events)
      end
      condition(:contribution_analytics_available, scope: :subject) do
        @subject.feature_available?(:contribution_analytics)
      end

      condition(:group_analytics_dashboards_available, scope: :subject) do
        @subject.feature_available?(:group_level_analytics_dashboard)
      end

      condition(:cycle_analytics_available, scope: :subject) do
        @subject.feature_available?(:cycle_analytics_for_groups)
      end

      condition(:group_ci_cd_analytics_available, scope: :subject) do
        @subject.feature_available?(:group_ci_cd_analytics)
      end

      condition(:group_repository_analytics_available, scope: :subject) do
        @subject.feature_available?(:group_repository_analytics)
      end

      condition(:group_coverage_reports_available, scope: :subject) do
        @subject.feature_available?(:group_coverage_reports)
      end

      condition(:group_activity_analytics_available, scope: :subject) do
        @subject.feature_available?(:group_activity_analytics)
      end

      condition(:group_devops_adoption_available, scope: :subject) do
        @subject.feature_available?(:group_level_devops_adoption)
      end

      condition(:group_credentials_inventory_available, scope: :subject) do
        ::Gitlab::Saas.feature_available?(:group_credentials_inventory) &&
          @subject.licensed_feature_available?(:credentials_inventory)
      end

      condition(:group_devops_adoption_enabled, scope: :global) do
        ::License.feature_available?(:group_level_devops_adoption)
      end

      condition(:dora4_analytics_available, scope: :subject) do
        @subject.feature_available?(:dora4_analytics)
      end

      condition(:group_membership_export_available, scope: :subject) do
        @subject.feature_available?(:export_user_permissions)
      end

      condition(:can_owners_manage_ldap, scope: :global) do
        ::Gitlab::CurrentSettings.allow_group_owners_to_manage_ldap?
      end

      condition(:memberships_locked_to_ldap, scope: :global) do
        ::Gitlab::CurrentSettings.lock_memberships_to_ldap?
      end

      condition(:memberships_locked_to_saml, scope: :global) do
        ::Gitlab::CurrentSettings.lock_memberships_to_saml
      end

      condition(:security_dashboard_enabled, scope: :subject) do
        @subject.feature_available?(:security_dashboard)
      end

      condition(:security_inventory_available, scope: :subject) do
        @subject.licensed_feature_available?(:security_inventory) &&
          ::Feature.enabled?(:security_inventory_dashboard, @subject.root_ancestor)
      end

      condition(:prevent_group_forking_available, scope: :subject) do
        @subject.feature_available?(:group_forking_protection)
      end

      condition(:needs_new_sso_session) do
        ::Gitlab::Auth::GroupSaml::SsoEnforcer.access_restricted?(user: @user, resource: @subject)
      end

      condition(:no_active_sso_session) do
        ::Gitlab::Auth::GroupSaml::SessionEnforcer.new(@user, @subject).access_restricted?
      end

      condition(:sso_enforced, scope: :subject) do
        saml_provider = @subject.root_ancestor.saml_provider
        next false unless saml_provider

        saml_provider.enabled? && saml_provider.enforced_sso?
      end

      condition(:ip_enforcement_prevents_access, scope: :subject) do
        !::Gitlab::IpRestriction::Enforcer.new(subject).allows_current_ip?
      end

      condition(:cluster_deployments_available, scope: :subject) do
        @subject.feature_available?(:cluster_deployments)
      end

      condition(:global_saml_enabled, scope: :global) do
        ::Gitlab::Auth::Saml::Config.enabled?
      end

      condition(:global_saml_group_sync_enabled, scope: :global) do
        ::AuthHelper.saml_providers.any? do |provider|
          ::Gitlab::Auth::Saml::Config.new(provider).group_sync_enabled?
        end
      end

      condition(:group_saml_globally_enabled, scope: :global) do
        ::Gitlab::Auth::GroupSaml::Config.enabled?
      end

      condition(:group_saml_enabled, scope: :subject) do
        @subject.group_saml_enabled?
      end

      condition(:group_saml_available, scope: :subject) do
        !@subject.subgroup? && @subject.feature_available?(:group_saml)
      end

      condition(:saml_group_sync_available, scope: :subject) do
        @subject.saml_group_sync_available?
      end

      condition(:commit_committer_check_available, scope: :subject) do
        @subject.feature_available?(:commit_committer_check)
      end

      condition(:commit_committer_name_check_available, scope: :subject) do
        @subject.feature_available?(:commit_committer_name_check)
      end

      condition(:reject_unsigned_commits_available, scope: :subject) do
        @subject.feature_available?(:reject_unsigned_commits)
      end

      condition(:reject_non_dco_commits_available, scope: :subject) do
        @subject.feature_available?(:reject_non_dco_commits)
      end

      condition(:push_rules_available, scope: :subject) do
        @subject.feature_available?(:push_rules)
      end

      condition(:group_merge_request_approval_settings_enabled, scope: :subject) do
        @subject.feature_available?(:merge_request_approvers) && @subject.root?
      end

      condition(:read_only, scope: :subject) { @subject.read_only? }

      condition(:eligible_for_trial, scope: :subject) { @subject.eligible_for_trial? }

      condition(:compliance_framework_available, scope: :subject) do
        @subject.feature_available?(:custom_compliance_frameworks)
      end

      condition(:group_level_compliance_pipeline_available, scope: :subject) do
        @subject.feature_available?(:evaluate_group_level_compliance_pipeline)
      end

      condition(:security_orchestration_policies_enabled, scope: :subject) do
        @subject.feature_available?(:security_orchestration_policies)
      end

      condition(:group_level_compliance_dashboard_enabled, scope: :subject) do
        @subject.feature_available?(:group_level_compliance_dashboard)
      end

      condition(:group_level_compliance_adherence_report_enabled, scope: :subject) do
        @subject.feature_available?(:group_level_compliance_adherence_report)
      end

      condition(:group_level_compliance_violations_report_enabled, scope: :subject) do
        @subject.feature_available?(:group_level_compliance_violations_report)
      end

      condition(:service_accounts_available, scope: :subject) do
        @subject.feature_available_non_trial?(:service_accounts)
      end

      condition(:user_banned_from_namespace) do
        next unless @user.is_a?(User)
        next if @user.can_admin_all_resources?

        root_namespace = @subject.root_ancestor
        next unless root_namespace.unique_project_download_limit_enabled?

        @user.banned_from_namespace?(root_namespace)
      end

      condition(:unique_project_download_limit_enabled) do
        @subject.unique_project_download_limit_enabled?
      end

      condition(:custom_roles_allowed) do
        @subject.custom_roles_enabled?
      end

      condition(:google_cloud_support_available, scope: :global) do
        ::Gitlab::Saas.feature_available?(:google_cloud_support)
      end

      condition(:allow_top_level_group_owners_to_create_service_accounts, scope: :global) do
        ::Gitlab::CurrentSettings.current_application_settings.allow_top_level_group_owners_to_create_service_accounts?
      end

      # score needs to be higher than reporter / developer / maintainer_access
      # so access_level condition is evaluated before any custom_role conditions
      MemberRole.all_customizable_group_permissions.each do |ability|
        desc "Custom role on group that enables #{ability.to_s.tr('_', ' ')}"
        condition(:"custom_role_enables_#{ability}", score: 65) do
          custom_role_ability(@user, @subject).allowed?(ability)
        end
      end

      condition(:admin_custom_role_enables_read_admin_cicd, scope: :user) do
        ::Authz::CustomAbility.allowed?(@user, :read_admin_cicd)
      end

      rule { admin_custom_role_enables_read_admin_cicd }.policy do
        enable :read_group_metadata
      end

      with_scope :subject
      condition(:generate_description_enabled) do
        ::Gitlab::Llm::FeatureAuthorizer.new(
          container: subject,
          feature_name: :generate_description,
          user: @user
        ).allowed?
      end

      with_scope :subject
      condition(:summarize_notes_allowed) do
        next false unless @user

        ::Gitlab::Llm::FeatureAuthorizer.new(
          container: subject,
          feature_name: :summarize_comments,
          user: @user
        ).allowed?
      end

      rule { custom_role_enables_read_code }.policy do
        enable :read_code
      end

      rule { owner & unique_project_download_limit_enabled }.policy do
        enable :ban_group_member
      end

      condition(:security_policy_project_available) do
        @subject.security_orchestration_policy_configuration.present?
      end

      condition(:can_commit_to_security_policy_project) do
        security_orchestration_policy_configuration = @subject.security_orchestration_policy_configuration

        next unless security_orchestration_policy_configuration

        Ability.allowed?(@user, :developer_access, security_orchestration_policy_configuration.security_policy_management_project)
      end

      condition(:chat_allowed_for_group, scope: :subject) do
        next true unless ::Gitlab::Saas.feature_available?(:duo_chat_on_saas)

        ::Gitlab::Llm::StageCheck.available?(@subject, :chat)
      end

      condition(:agentic_chat_allowed_for_group, scope: :subject) do
        next true unless ::Gitlab::Saas.feature_available?(:duo_chat_on_saas)

        ::Gitlab::Llm::StageCheck.available?(@subject, :agentic_chat)
      end

      condition(:chat_available_for_user, scope: :user) do
        Ability.allowed?(@user, :access_duo_chat)
      end

      condition(:agentic_chat_available_for_user, scope: :user) do
        Ability.allowed?(@user, :access_duo_agentic_chat)
      end

      condition(:duo_features_enabled, scope: :subject) { @subject.namespace_settings&.duo_features_enabled }

      condition(:runner_performance_insights_available, scope: :subject) do
        @subject.licensed_feature_available?(:runner_performance_insights_for_namespace)
      end

      condition(:clickhouse_main_database_available, scope: :global) do
        ::Gitlab::ClickHouse.configured?
      end

      condition(:default_roles_assignees_allowed, scope: :subject) do
        @subject.root_ancestor.licensed_feature_available?(:default_roles_assignees)
      end

      condition(:resolve_vulnerability_allowed) do
        ::Gitlab::Llm::FeatureAuthorizer.new(
          container: subject,
          feature_name: :resolve_vulnerability,
          user: @user
        ).allowed?
      end

      condition(:ai_catalog_enabled, scope: :user) do
        ::Feature.enabled?(:global_ai_catalog, @user)
      end

      rule { user_banned_from_namespace }.prevent_all

      rule { public_group | logged_in_viewable }.policy do
        enable :read_wiki
        enable :download_wiki_code
      end

      rule { guest }.policy do
        enable :read_wiki
        enable :read_group_release_stats

        # Only used on specific scenario to filter out subgroup epics not visible
        # to user when showing parent group epics list
        enable :list_subgroup_epics
      end

      rule { planner }.policy do
        enable :create_wiki
        enable :admin_wiki
        enable :download_wiki_code
      end

      rule { reporter }.policy do
        enable :admin_issue_board_list
        enable :view_productivity_analytics
        enable :download_wiki_code
        enable :read_customizable_dashboards
      end

      rule { maintainer }.policy do
        enable :maintainer_access
        enable :admin_wiki
        enable :modify_product_analytics_settings
        enable :read_jobs_statistics
        enable :read_runner_usage
        enable :admin_push_rules
        enable :admin_security_testing
        enable :admin_ai_catalog_item_consumer
      end

      rule { (admin | maintainer) & group_analytics_dashboards_available & ~has_parent }.policy do
        enable :modify_value_stream_dashboard_settings
      end

      rule { auditor }.policy do
        enable :view_productivity_analytics
        enable :view_group_devops_adoption
        enable :read_group_repository_analytics
        enable :read_group_contribution_analytics
        enable :read_cycle_analytics
        enable :read_cluster # Deprecated as certificate-based cluster integration (`Clusters::Cluster`).
        enable :read_cluster_agent
        enable :read_dependency_proxy
        enable :read_wiki
        enable :read_billable_member

        enable :read_group_all_available_runners
        enable :read_runners
      end

      rule { auditor & group_ci_cd_analytics_available }.policy do
        enable :view_group_ci_cd_analytics
        enable :read_group_release_stats
      end

      rule { owner }.policy do
        enable :admin_protected_environments
        enable :admin_licensed_seat
      end

      rule { can?(:owner_access) }.policy do
        enable :admin_compliance_framework
        enable :manage_deploy_tokens
        enable :set_epic_created_at
        enable :set_epic_updated_at
      end

      rule { can?(:read_cluster) & cluster_deployments_available }
        .enable :read_cluster_environments

      rule { has_access & contribution_analytics_available }
        .enable :read_group_contribution_analytics

      rule { has_access & group_activity_analytics_available }
        .enable :read_group_activity_analytics

      rule { (admin | reporter | auditor) & dora4_analytics_available }
        .enable :read_dora4_analytics

      condition(:ai_review_mr_enabled) do
        @subject.duo_features_enabled
      end

      condition(:user_allowed_to_use_ai_review_mr) do
        @user&.allowed_to_use?(:review_merge_request, licensed_feature: :review_merge_request)
      end

      rule do
        ai_review_mr_enabled &
          user_allowed_to_use_ai_review_mr
      end.enable :access_ai_review_mr

      condition(:assigned_to_duo_enterprise) do
        @user.assigned_to_duo_enterprise?(@subject)
      end

      condition(:assigned_to_duo_pro) do
        @user.assigned_to_duo_pro?(@subject)
      end

      condition(:amazon_q_enabled) do
        ::Ai::AmazonQ.enabled?
      end

      condition(:duo_usage_analytics_enabled) do
        ::Feature.enabled?(:duo_usage_dashboard, @subject.root_ancestor) && @user.assigned_to_duo_add_ons?(@subject)
      end

      rule { can?(:read_customizable_dashboards) & (amazon_q_enabled | assigned_to_duo_pro) }.enable :read_pro_ai_analytics
      rule { can?(:read_customizable_dashboards) & (amazon_q_enabled | assigned_to_duo_enterprise) }.enable :read_enterprise_ai_analytics

      rule { can?(:read_customizable_dashboards) & duo_usage_analytics_enabled }.enable :read_duo_usage_analytics

      rule { reporter & group_repository_analytics_available }
        .enable :read_group_repository_analytics

      rule { reporter & group_coverage_reports_available }
        .enable :read_group_coverage_reports

      rule { reporter & group_analytics_dashboards_available }.policy do
        enable :read_group_analytics_dashboards
      end

      rule { (reporter | admin) & cycle_analytics_available }.policy do
        enable :admin_value_stream
        enable :create_group_stage
        enable :delete_group_stage
        enable :read_cycle_analytics
        enable :read_group_stage
        enable :update_group_stage
        enable :view_type_of_work_charts
      end

      rule { auditor & cycle_analytics_available }.policy do
        enable :read_cycle_analytics
        enable :read_group_stage
        enable :view_type_of_work_charts
      end

      rule { reporter & group_ci_cd_analytics_available }.policy do
        enable :view_group_ci_cd_analytics
      end

      rule { reporter & group_devops_adoption_enabled & group_devops_adoption_available }.policy do
        enable :manage_devops_adoption_namespaces
        enable :view_group_devops_adoption
      end

      rule { admin & group_devops_adoption_enabled }.policy do
        enable :manage_devops_adoption_namespaces
      end

      rule { owner & ~has_parent & prevent_group_forking_available }.policy do
        enable :change_prevent_group_forking
      end

      rule { can?(:read_group) & epics_available }.policy do
        enable :read_epic
        enable :read_epic_board
        enable :read_epic_board_list
      end

      rule { can?(:read_group) & iterations_available }.policy do
        enable :read_iteration
        enable :read_iteration_cadence
      end

      rule { (reporter | planner) & iterations_available }.policy do
        enable :create_iteration
        enable :admin_iteration
        enable :create_iteration_cadence
        enable :admin_iteration_cadence
      end

      rule { (automation_bot | reporter) & iterations_available }.policy do
        enable :rollover_issues
      end

      rule { (reporter | planner) & epics_available }.policy do
        enable :create_epic
        enable :admin_epic
        enable :update_epic
        enable :read_confidential_epic
        enable :admin_epic_board
        enable :admin_epic_board_list
      end

      rule { (owner | planner) & epics_available }.enable :destroy_epic

      rule { can?(:read_group) & custom_fields_available }.policy do
        enable :read_custom_field
      end

      rule { maintainer & custom_fields_available }.policy do
        enable :admin_custom_field
      end

      rule { can?(:read_work_item) & work_item_statuses_available }.policy do
        enable :read_work_item_lifecycle
        enable :read_work_item_status
      end

      rule { maintainer & work_item_statuses_available }.policy do
        enable :admin_work_item_lifecycle
      end

      rule { ~can?(:read_cross_project) }.policy do
        prevent :read_group_contribution_analytics
        prevent :read_epic
        prevent :read_confidential_epic
        prevent :create_epic
        prevent :admin_epic
        prevent :update_epic
        prevent :destroy_epic
        prevent :admin_epic_board_list
      end

      rule { auditor }.policy do
        enable :read_group
        enable :read_group_audit_events
        enable :read_billing
        enable :read_container_image
      end

      rule { group_saml_globally_enabled & group_saml_available & (admin | owner) }.enable :admin_group_saml

      rule { saml_group_sync_available & (admin | owner) }.policy do
        enable :admin_saml_group_links
      end

      rule { global_saml_enabled & global_saml_group_sync_enabled & (admin | owner) }.policy do
        enable :admin_saml_group_links
      end

      rule { admin | (can_owners_manage_ldap & owner) }.policy do
        enable :admin_ldap_group_links
      end

      rule { ldap_synced }.prevent :admin_group_member

      rule { ldap_synced & (admin | owner) }.enable :update_group_member

      rule { ldap_synced & (admin | (can_owners_manage_ldap & owner)) }.enable :override_group_member

      rule { memberships_locked_to_ldap & ~admin }.policy do
        prevent :admin_group_member
        prevent :update_group_member
        prevent :override_group_member
      end

      rule { (admin | owner) & service_accounts_available }.policy do
        enable :admin_service_accounts
        enable :admin_service_account_member
      end

      rule { memberships_locked_to_saml & saml_group_sync_available & saml_group_links_exists & ~admin }.policy do
        prevent :admin_group_member
      end

      rule { service_accounts_available & ~has_parent & (admin | (allow_top_level_group_owners_to_create_service_accounts & owner)) }.policy do
        enable :create_service_account
        enable :delete_service_account
      end

      rule { developer }.policy do
        enable :create_wiki
        enable :admin_merge_request
        enable :read_group_audit_events
        enable :read_vulnerability_statistics
        enable :read_security_inventory
        enable :read_ai_catalog_item_consumer
      end

      rule { security_orchestration_policies_enabled & can?(:developer_access) }.policy do
        enable :read_security_orchestration_policies
      end

      rule { security_orchestration_policies_enabled & auditor }.policy do
        enable :read_security_orchestration_policies
      end

      rule { security_orchestration_policies_enabled & can?(:owner_access) }.policy do
        enable :update_security_orchestration_policy_project
      end

      rule { security_orchestration_policies_enabled & can?(:owner_access) & ~security_policy_project_available }.policy do
        enable :modify_security_policy
      end

      rule { security_orchestration_policies_enabled & security_policy_project_available & can_commit_to_security_policy_project }.policy do
        enable :modify_security_policy
      end

      rule { security_orchestration_policies_enabled & custom_role_enables_manage_security_policy_link }.policy do
        enable :read_security_orchestration_policies
        enable :read_security_orchestration_policy_project
        enable :update_security_orchestration_policy_project
      end

      rule { security_dashboard_enabled & (auditor | developer) }.policy do
        enable :read_dependency
        enable :read_vulnerability
      end

      rule { security_dashboard_enabled & can?(:maintainer_access) }.policy do
        enable :admin_vulnerability
      end

      rule { can?(:maintainer_access) }.policy do
        enable :admin_security_attributes
      end

      rule { custom_role_enables_admin_security_attributes }.enable(:admin_security_attributes)

      rule { ~security_inventory_available }.prevent :read_security_inventory

      rule { custom_role_enables_read_dependency }.policy do
        enable :read_dependency
      end

      rule { custom_role_enables_read_vulnerability }.policy do
        enable :read_vulnerability
      end

      rule { custom_role_enables_admin_vulnerability }.policy do
        enable :admin_vulnerability
        enable :read_security_inventory
      end

      rule { custom_role_enables_admin_security_testing }.policy do
        enable :admin_security_testing
      end

      rule { security_dashboard_enabled & can?(:admin_security_testing) }.policy do
        enable :access_security_and_compliance
        enable :read_security_configuration
        enable :read_group_security_dashboard
        enable :read_security_resource
      end

      rule { secret_push_protection_available & can?(:admin_security_testing) }.policy do
        enable :enable_secret_push_protection
      end

      rule { custom_role_enables_admin_group_member }.policy do
        enable :admin_group_member
        enable :update_group_member
        enable :destroy_group_member
        enable :read_billable_member
      end

      rule { custom_role_enables_admin_group_member & ~owner }.policy do
        prevent :activate_group_member
      end

      rule { custom_role_enables_read_crm_contact }.enable(:read_crm_contact)

      rule { custom_role_enables_admin_group_member & service_accounts_available }.policy do
        enable :admin_service_account_member
      end

      rule { custom_role_enables_manage_group_access_tokens & resource_access_token_feature_available }.policy do
        enable :read_resource_access_tokens
        enable :destroy_resource_access_tokens
      end

      rule { custom_role_enables_manage_group_access_tokens & resource_access_token_creation_allowed }.policy do
        enable :create_resource_access_tokens
        enable :manage_resource_access_tokens
      end

      rule { custom_roles_allowed & guest }.policy do
        enable :read_member_role
      end

      rule { default_roles_assignees_allowed & owner }.policy do
        enable :view_member_roles
      end

      rule { custom_roles_allowed & owner }.policy do
        enable :admin_member_role
        enable :view_member_roles
      end

      rule { ~is_gitlab_com }.prevent :admin_member_role

      rule { custom_role_enables_admin_cicd_variables }.policy do
        enable :admin_cicd_variables
      end

      rule { custom_role_enables_admin_protected_environments }.policy do
        enable :admin_protected_environments
      end

      rule { custom_role_enables_admin_compliance_framework }.policy do
        enable :admin_compliance_framework
        enable :admin_compliance_pipeline_configuration
        enable :read_compliance_dashboard
        enable :read_compliance_adherence_report
        enable :read_compliance_violations_report
      end

      rule { custom_role_enables_read_compliance_dashboard }.policy do
        enable :read_compliance_dashboard
        enable :read_compliance_adherence_report
        enable :read_compliance_violations_report
      end

      rule { ~compliance_framework_available }.policy do
        prevent :admin_compliance_framework
      end

      rule { ~group_level_compliance_pipeline_available }.policy do
        prevent :admin_compliance_pipeline_configuration
      end

      rule { ~group_level_compliance_dashboard_enabled }.policy do
        prevent :read_compliance_dashboard
      end

      rule { ~group_level_compliance_adherence_report_enabled }.policy do
        prevent :read_compliance_adherence_report
      end

      rule { ~group_level_compliance_violations_report_enabled }.policy do
        prevent :read_compliance_violations_report
      end

      condition(:any_projects_except_soft_deleted) do
        @subject.all_projects.non_archived.not_aimed_for_deletion.exists?
      end

      rule { custom_role_enables_remove_group & has_parent }.policy do
        enable :remove_group
      end

      rule { ~admin & owner_cannot_destroy_project & any_projects_except_soft_deleted }.policy do
        prevent :remove_group
      end

      rule { custom_role_enables_admin_push_rules }.policy do
        enable :admin_push_rules
      end

      rule { custom_role_enables_admin_integrations }.policy do
        enable :admin_integrations
      end

      rule { custom_role_enables_read_runners }.policy do
        enable :read_runners
      end

      rule { can?(:admin_group) | can?(:admin_compliance_framework) | can?(:manage_deploy_tokens) | can?(:manage_merge_request_settings) }.policy do
        enable :view_edit_page
      end

      rule { custom_role_enables_manage_deploy_tokens }.policy do
        enable :manage_deploy_tokens
        enable :read_deploy_token
        enable :create_deploy_token
        enable :destroy_deploy_token
      end

      rule { can?(:read_vulnerability) }.policy do
        enable :read_group_security_dashboard
        enable :create_vulnerability_export
        enable :read_security_resource
        enable :read_vulnerability_statistics
      end

      rule { can?(:read_security_resource) & resolve_vulnerability_allowed }.policy do
        enable :resolve_vulnerability_with_ai
      end

      rule { custom_role_enables_manage_merge_request_settings }.policy do
        enable :manage_merge_request_settings
      end

      rule { can?(:manage_merge_request_settings) & group_merge_request_approval_settings_enabled }.policy do
        enable :admin_merge_request_approval_settings
      end

      rule { can?(:admin_vulnerability) }.policy do
        enable :read_vulnerability
      end

      rule { can?(:read_dependency) }.policy do
        enable :read_licenses
      end

      rule { custom_role_enables_admin_runners }.policy do
        enable :admin_runners
        enable :create_runners
        enable :read_group_all_available_runners
        enable :read_runners
      end

      rule { admin | owner }.policy do
        enable :owner_access
        enable :read_billable_member
        enable :admin_ci_minutes
      end

      rule { (admin | owner) & group_credentials_inventory_available & ~has_parent }.policy do
        enable :read_group_credentials_inventory
        enable :admin_group_credentials_inventory
      end

      rule { (admin | owner | auditor) & group_level_compliance_dashboard_enabled }.policy do
        enable :read_compliance_dashboard
      end

      rule { (admin | owner | auditor) & group_level_compliance_adherence_report_enabled }.policy do
        enable :read_compliance_adherence_report
      end

      rule { (admin | owner | auditor) & group_level_compliance_violations_report_enabled }.policy do
        enable :read_compliance_violations_report
      end

      rule { (admin | owner) & group_merge_request_approval_settings_enabled }.policy do
        enable :admin_merge_request_approval_settings
        enable :update_approval_rule
      end

      rule { needs_new_sso_session }.policy do
        prevent :read_group
      end

      rule { ip_enforcement_prevents_access & ~owner & ~auditor }.policy do
        prevent_all
      end

      rule { owner & group_saml_enabled }.policy do
        enable :read_group_saml_identity
        enable :read_group_scim_identity
      end

      rule { ~(admin | allow_to_manage_default_branch_protection) }.policy do
        prevent :update_default_branch_protection
      end

      desc "Group has wiki disabled"
      condition(:wiki_disabled, score: 32) do
        !@subject.licensed_feature_available?(:group_wikis) || !@subject.feature_available?(:wiki, @user)
      end

      desc "Group has saved replies support"
      condition(:supports_saved_replies) do
        @subject.supports_saved_replies?
      end

      rule { wiki_disabled }.policy do
        prevent :read_wiki
        prevent :create_wiki
        prevent :update_wiki
        prevent :admin_wiki
        prevent :destroy_wiki
        prevent :download_wiki_code
      end

      rule { can?(:admin_push_rules) }.policy do
        enable :change_push_rules
        enable :change_commit_committer_check
        enable :change_commit_committer_name_check
        enable :change_reject_unsigned_commits
        enable :change_reject_non_dco_commits
      end

      rule { ~push_rules_available }.policy do
        prevent :change_push_rules
      end

      rule { ~commit_committer_check_available }.policy do
        prevent :change_commit_committer_check
      end

      rule { ~commit_committer_name_check_available }.policy do
        prevent :change_commit_committer_name_check
      end

      rule { ~reject_unsigned_commits_available }.policy do
        prevent :change_reject_unsigned_commits
      end

      rule { ~reject_non_dco_commits_available }.policy do
        prevent :change_reject_non_dco_commits
      end

      rule { admin & is_gitlab_com }.enable :update_subscription_limit

      rule { maintainer & eligible_for_trial }.enable :start_trial

      rule { read_only }.policy do
        prevent :create_epic
        prevent :update_epic
        prevent :admin_pipeline
        prevent :register_group_runners
        prevent :create_runners
        prevent :update_runner
        prevent :add_cluster
        prevent :create_cluster
        prevent :update_cluster
        prevent :admin_cluster
        prevent :create_deploy_token
        prevent :create_subgroup
        prevent :create_package
      end

      rule { can?(:owner_access) & group_membership_export_available }.enable :export_group_memberships
      rule { can?(:owner_access) & group_level_compliance_pipeline_available }.enable :admin_compliance_pipeline_configuration
      rule { can?(:owner_access) & external_audit_events_available }.policy do
        enable :admin_external_audit_events
      end

      # Special case to allow support bot assigning service desk
      # issues to epics in private groups using quick actions
      rule { support_bot & epics_available & has_project_with_service_desk_enabled }.policy do
        enable :read_epic
        enable :read_issue
        enable :read_epic_iid
      end

      rule { guest }.enable :read_limit_alert

      rule { can?(:read_group) & chat_allowed_for_group & chat_available_for_user & duo_features_enabled }.enable :access_duo_chat
      rule { can?(:read_group) & agentic_chat_allowed_for_group & agentic_chat_available_for_user & duo_features_enabled & ~amazon_q_enabled }.enable :access_duo_agentic_chat

      rule { can?(:read_group) & duo_features_enabled }.enable :access_duo_features

      rule { can?(:admin_group_member) & sso_enforced }.policy do
        enable :read_saml_user
      end

      rule { supports_saved_replies & guest }.enable :read_saved_replies

      rule { supports_saved_replies & developer }.policy do
        enable :create_saved_replies
        enable :destroy_saved_replies
        enable :update_saved_replies
      end

      rule { google_cloud_support_available & can?(:maintainer_access) }.policy do
        enable :read_runner_cloud_provisioning_info
        enable :read_runner_gke_provisioning_info
        enable :provision_cloud_runner
        enable :provision_gke_runner
      end

      rule { ~runner_performance_insights_available }.policy do
        prevent :read_runner_usage
        prevent :read_jobs_statistics
      end

      rule { ~clickhouse_main_database_available }.prevent :read_runner_usage

      condition(:secret_push_protection_available) do
        @subject.licensed_feature_available?(:secret_push_protection)
      end

      rule { secret_push_protection_available & can?(:maintainer_access) }.policy do
        enable :enable_secret_push_protection
      end

      rule { can?(:admin_group) }.policy do
        enable :read_web_hook
        enable :admin_web_hook
      end

      rule { custom_role_enables_admin_web_hook }.policy do
        enable :read_web_hook
        enable :admin_web_hook
      end

      condition(:bulk_edit_feature_available, scope: :subject) do
        @subject.licensed_feature_available?(:group_bulk_edit)
      end

      condition(:disable_invite_members_for_group, scope: :subject) do
        ::Gitlab::Saas.feature_available?(:group_disable_invite_members) &&
          @subject.licensed_feature_available?(:disable_invite_members) &&
          @subject.root_ancestor.disable_invite_members?
      end

      condition(:disable_invite_members, scope: :global) do
        ::License.feature_available?(:disable_invite_members) &&
          ::Gitlab::CurrentSettings.current_application_settings.disable_invite_members?
      end

      rule { can?(:admin_epic) & bulk_edit_feature_available }.policy do
        enable :bulk_admin_epic
      end

      rule { ~admin & (~is_gitlab_com & disable_invite_members) }.policy do
        prevent :invite_group_members
      end

      rule { ~admin & disable_invite_members_for_group }.policy do
        prevent :invite_group_members
      end

      with_scope :subject
      condition(:duo_workflow_available) do
        @subject.duo_features_enabled &&
          ::Gitlab::Llm::StageCheck.available?(@subject, :duo_workflow) &&
          @user&.allowed_to_use?(:duo_agent_platform)
      end

      rule { duo_workflow_available & can?(:admin_group) }.policy do
        enable :admin_duo_workflow
      end

      rule { duo_workflow_token & ~duo_features_enabled }.prevent_all

      rule do
        summarize_notes_allowed & can?(:read_work_item)
      end.enable :summarize_comments

      rule do
        generate_description_enabled & can?(:create_work_item)
      end.enable :generate_description

      with_scope :subject
      condition(:group_model_selection_enabled) do
        next false unless subject.root?
        next false if ::Ai::Setting.self_hosted?
        next false unless ::Feature.enabled?(:ai_model_switching, subject)

        subject.namespace_settings&.duo_features_enabled?
      end

      rule { ~ai_catalog_enabled }.policy do
        prevent :admin_ai_catalog_item_consumer
        prevent :read_ai_catalog_item_consumer
      end

      rule { can?(:admin_group) & group_model_selection_enabled }.enable :admin_group_model_selection
    end

    override :lookup_access_level!
    def lookup_access_level!(for_any_session: false)
      if for_any_session
        return ::GroupMember::NO_ACCESS if no_active_sso_session?
      elsif needs_new_sso_session?
        return ::GroupMember::NO_ACCESS
      end

      super
    end

    override :can_read_group_member?
    def can_read_group_member?
      return true if user&.can_read_all_resources?

      super
    end

    # Available in Core for self-managed but only paid, non-trial for .com to prevent abuse
    override :resource_access_token_create_feature_available?
    def resource_access_token_create_feature_available?
      return false unless resource_access_token_feature_available?
      return super unless ::Gitlab.com?

      group.feature_available_non_trial?(:resource_access_token)
    end

    override :resource_access_token_feature_available?
    def resource_access_token_feature_available?
      return false if ::Gitlab::CurrentSettings.personal_access_tokens_disabled?

      super
    end

    def custom_role_ability(user, subject)
      strong_memoize_with(:custom_role_ability, user, subject) do
        ::Authz::CustomAbility.new(user, subject)
      end
    end
  end
end
