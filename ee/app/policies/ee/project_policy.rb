# frozen_string_literal: true

module EE
  module ProjectPolicy
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    prepended do
      include ReadonlyAbilities
      include ::Gitlab::Utils::StrongMemoize
      include Vulnerabilities::AdvancedVulnerabilityManagementPolicy

      desc "User is a security policy bot on the project"
      condition(:security_policy_bot) { user&.security_policy_bot? && team_member? }

      with_scope :subject
      condition(:repository_mirrors_enabled) { @subject.feature_available?(:repository_mirrors) }

      with_scope :subject
      condition(:iterations_available) { @subject.group&.licensed_feature_available?(:iterations) }

      with_scope :subject
      condition(:requirements_available) { @subject.feature_available?(:requirements) & access_allowed_to?(:requirements) }

      with_scope :subject
      condition(:quality_management_available) { @subject.feature_available?(:quality_management) }

      condition(:compliance_framework_available) { @subject.feature_available?(:compliance_framework, @user) }

      with_scope :subject
      condition(:project_level_compliance_dashboard_enabled) do
        in_group? && @subject.feature_available?(:project_level_compliance_dashboard)
      end

      with_scope :subject
      condition(:project_level_compliance_adherence_report_enabled) do
        in_group? && @subject.feature_available?(:project_level_compliance_adherence_report)
      end

      with_scope :subject
      condition(:project_level_compliance_violations_report_enabled) do
        in_group? && @subject.feature_available?(:project_level_compliance_violations_report)
      end

      with_scope :subject
      condition(:project_epics_available) do
        @subject.project_epics_enabled? && @subject.licensed_feature_available?(:epics)
      end

      with_scope :global
      condition(:is_development) { Rails.env.development? }

      with_scope :global
      condition(:ai_available) do
        ::Feature.enabled?(:ai_global_switch, type: :ops)
      end

      with_scope :global
      condition(:locked_approvers_rules) do
        !@user.can_admin_all_resources? &&
          License.feature_available?(:admin_merge_request_approvers_rules) &&
          ::Gitlab::CurrentSettings.disable_overriding_approvers_per_merge_request
      end

      with_scope :subject
      condition(:disable_invite_members_for_group) do
        ::Gitlab::Saas.feature_available?(:group_disable_invite_members) &&
          @subject.group &&
          @subject.group.root_ancestor.licensed_feature_available?(:disable_invite_members) &&
          @subject.group.root_ancestor.disable_invite_members?
      end

      with_scope :global
      condition(:disable_invite_members) do
        License.feature_available?(:disable_invite_members) &&
          ::Gitlab::CurrentSettings.current_application_settings.disable_invite_members?
      end

      condition(:group_merge_request_approval_settings_enabled) do
        @subject.feature_available?(:merge_request_approvers)
      end

      with_scope :global
      condition(:locked_merge_request_author_setting) do
        License.feature_available?(:admin_merge_request_approvers_rules) &&
          ::Gitlab::CurrentSettings.prevent_merge_requests_author_approval
      end

      with_scope :global
      condition(:locked_merge_request_committer_setting) do
        License.feature_available?(:admin_merge_request_approvers_rules) &&
          ::Gitlab::CurrentSettings.prevent_merge_requests_committers_approval
      end

      with_scope :subject
      condition(:dora4_analytics_available) do
        @subject.feature_available?(:dora4_analytics)
      end

      condition(:project_merge_request_analytics_available) do
        @subject.feature_available?(:project_merge_request_analytics)
      end

      condition(:push_rules_available, scope: :subject) do
        @subject.feature_available?(:push_rules)
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

      condition(:security_orchestration_policies_enabled, scope: :subject) do
        @subject.feature_available?(:security_orchestration_policies)
      end

      condition(:security_dashboard_enabled, scope: :subject) do
        @subject.feature_available?(:security_dashboard)
      end

      condition(:security_scans_api_enabled, scope: :subject) do
        ::Gitlab::Saas.feature_available?(:security_scans_api) &&
          @subject.licensed_feature_available?(:security_scans_api)
      end

      condition(:coverage_fuzzing_enabled, scope: :subject) do
        @subject.feature_available?(:coverage_fuzzing)
      end

      condition(:on_demand_scans_enabled, scope: :subject) do
        @subject.on_demand_dast_available?
      end

      condition(:license_scanning_enabled, scope: :subject) do
        @subject.feature_available?(:license_scanning)
      end

      condition(:dependency_scanning_enabled, scope: :subject) do
        @subject.feature_available?(:dependency_scanning)
      end

      condition(:code_review_analytics_enabled) do
        @subject.feature_available?(:code_review_analytics, @user)
      end

      condition(:issue_analytics_enabled) do
        @subject.feature_available?(:issues_analytics, @user)
      end

      condition(:combined_project_analytics_dashboards_enabled) do
        @subject.feature_available?(:combined_project_analytics_dashboards, @user)
      end

      condition(:google_cloud_support_available, scope: :global) do
        ::Gitlab::Saas.feature_available?(:google_cloud_support)
      end

      condition(:status_page_available) do
        @subject.feature_available?(:status_page, @user)
      end

      condition(:read_only, scope: :subject) do
        @subject.root_namespace.read_only?
      end

      condition(:feature_flags_related_issues_disabled, scope: :subject) do
        !@subject.feature_available?(:feature_flags_related_issues)
      end

      condition(:oncall_schedules_available, scope: :subject) do
        ::Gitlab::IncidentManagement.oncall_schedules_available?(@subject)
      end

      condition(:escalation_policies_available, scope: :subject) do
        ::Gitlab::IncidentManagement.escalation_policies_available?(@subject)
      end

      condition(:hidden, scope: :subject) do
        @subject.hidden?
      end

      condition(:membership_locked_via_parent_group, scope: :subject) do
        @subject.group && (
          @subject.group.membership_lock? ||
          ::Gitlab::CurrentSettings.lock_memberships_to_ldap? ||
          ::Gitlab::CurrentSettings.lock_memberships_to_saml)
      end

      condition(:security_policy_project_available, scope: :subject) do
        @subject.security_orchestration_policy_configuration.present?
      end

      condition(:can_commit_to_security_policy_project) do
        security_orchestration_policy_configuration = @subject.security_orchestration_policy_configuration

        next unless security_orchestration_policy_configuration

        Ability.allowed?(@user, :developer_access, security_orchestration_policy_configuration.security_policy_management_project)
      end

      condition(:okrs_enabled, scope: :subject) do
        @subject.okrs_mvc_feature_flag_enabled? && @subject.feature_available?(:okrs)
      end

      condition(:licensed_cycle_analytics_available, scope: :subject) do
        @subject.feature_available?(:cycle_analytics_for_projects)
      end

      condition(:agent_registry_enabled, scope: :subject) do
        ::Feature.enabled?(:agent_registry, @subject) && @subject.licensed_feature_available?(:ai_agents)
      end

      condition(:user_banned_from_namespace) do
        next unless @user.is_a?(User)
        next if @user.can_admin_all_resources?
        # Loading the namespace_bans association is intentional because it is going to
        # be used in the banned_from_namespace? check below
        next if @user.namespace_bans.to_a.empty?

        groups = @subject.invited_groups + [@subject.group]
        groups.compact!
        next if groups.empty?

        groups.any? do |group|
          next unless group.root_ancestor.unique_project_download_limit_enabled?

          @user.banned_from_namespace?(group.root_ancestor)
        end
      end

      rule { membership_locked_via_parent_group }.policy do
        prevent :import_project_members_from_another_project
        prevent :invite_member
      end

      condition(:custom_roles_allowed) do
        @subject.custom_roles_enabled?
      end

      # score needs to be higher than reporter / developer / maintainer_access
      # so access_level condition is evaluated before any custom_role conditions
      MemberRole.all_customizable_project_permissions.each do |ability|
        desc "Custom role on project that enables #{ability.to_s.tr('_', ' ')}"
        condition(:"custom_role_enables_#{ability}", score: 210) do
          custom_role_ability(@user, @subject).allowed?(ability)
        end
      end

      MemberRole.all_customizable_admin_permission_keys.each do |ability|
        desc "Admin custom role that enables #{ability.to_s.tr('_', ' ')}"
        condition(:"admin_custom_role_enables_#{ability}", scope: :user) do
          ::Authz::CustomAbility.new(@user).allowed?(ability)
        end
      end

      with_scope :subject
      condition(:suggested_reviewers_available) do
        @subject.can_suggest_reviewers?
      end

      condition(:summarize_new_merge_request_enabled) do
        ::Feature.enabled?(:add_ai_summary_for_new_mr, subject) &&
          ::Gitlab::Llm::FeatureAuthorizer.new(
            container: subject,
            feature_name: :summarize_new_merge_request,
            user: @user,
            licensed_feature: :summarize_new_merge_request
          ).allowed?
      end

      condition(:generate_description_enabled) do
        ::Gitlab::Llm::FeatureAuthorizer.new(
          container: subject,
          feature_name: :generate_description,
          user: @user
        ).allowed?
      end

      condition(:summarize_notes_allowed) do
        next false unless @user

        ::Gitlab::Llm::FeatureAuthorizer.new(
          container: subject,
          feature_name: :summarize_comments,
          user: @user
        ).allowed?
      end

      with_scope :subject
      condition(:target_branch_rules_available) { subject.licensed_feature_available?(:target_branch_rules) }

      condition(:pages_multiple_versions_available) do
        @subject.licensed_feature_available?(:pages_multiple_versions)
      end

      condition(:merge_requests_is_a_private_feature) do
        project.project_feature&.private?(:merge_requests)
      end

      condition(:observability_enabled) do
        ::Feature.enabled?(:observability_features, @subject.root_namespace) &&
          @subject.licensed_feature_available?(:observability)
      end

      # We are overriding the already defined condition in CE version
      # to allow Guest users with member roles to access the merge requests.
      condition(:merge_requests_disabled) do
        !(access_allowed_to?(:merge_requests) ||
          (merge_requests_is_a_private_feature? && custom_role_enables_admin_merge_request?))
      end

      condition(:ai_catalog_enabled, scope: :user) do
        ::Feature.enabled?(:global_ai_catalog, @user)
      end

      rule { custom_role_enables_admin_cicd_variables }.policy do
        enable :admin_cicd_variables
      end

      rule { custom_role_enables_admin_protected_environments }.policy do
        enable :admin_protected_environments
      end

      rule { custom_role_enables_admin_push_rules }.policy do
        enable :admin_push_rules
      end

      rule { custom_role_enables_manage_protected_tags }.policy do
        enable :manage_protected_tags
      end

      rule { can?(:manage_protected_tags) }.policy do
        enable :read_protected_tags
        enable :create_protected_tags
        enable :update_protected_tags
        enable :destroy_protected_tags
      end

      rule { custom_role_enables_admin_integrations }.policy do
        enable :admin_integrations
      end

      rule { custom_role_enables_admin_runners }.policy do
        enable :admin_runners
        enable :create_runners
      end

      rule { can?(:admin_runners) }.enable :read_runners

      rule { custom_role_enables_read_runners }.enable :read_runners

      rule { admin_custom_role_enables_read_admin_cicd }.policy do
        enable :read_project_metadata
      end

      condition(:ci_cancellation_maintainers_only, scope: :subject) do
        project.ci_cancellation_restriction.maintainers_only_allowed?
      end

      condition(:ci_cancellation_no_one, scope: :subject) do
        project.ci_cancellation_restriction.no_one_allowed?
      end

      condition(:chat_allowed_for_parent_group, scope: :subject) do
        next true unless ::Gitlab::Saas.feature_available?(:duo_chat_on_saas)

        ::Gitlab::Llm::StageCheck.available?(@subject.parent, :chat)
      end

      condition(:chat_available_for_user, scope: :user) do
        Ability.allowed?(@user, :access_duo_chat)
      end

      condition(:duo_features_enabled, scope: :subject) { @subject.duo_features_enabled }

      rule { visual_review_bot }.policy do
        prevent_all
      end

      rule { license_block }.policy do
        prevent :create_issue
        prevent :create_merge_request_in
        prevent :create_merge_request_from
        prevent :push_code
      end

      rule { analytics_disabled }.policy do
        prevent(:read_project_merge_request_analytics)
        prevent(:read_code_review_analytics)
        prevent(:read_issue_analytics)
      end

      rule { ~admin & (~is_gitlab_com & disable_invite_members) }.policy do
        prevent :invite_project_members
      end

      rule { ~admin & disable_invite_members_for_group }.policy do
        prevent :invite_project_members
      end

      rule { feature_flags_related_issues_disabled | repository_disabled }.policy do
        prevent :admin_feature_flags_issue_links
      end

      rule { can?(:guest_access) & iterations_available }.enable :read_iteration

      rule { can?(:reporter_access) }.policy do
        enable :admin_issue_board
        enable :read_customizable_dashboards
      end

      rule { monitor_disabled }.policy do
        prevent :read_incident_management_oncall_schedule
        prevent :admin_incident_management_oncall_schedule
        prevent :read_incident_management_escalation_policy
        prevent :admin_incident_management_escalation_policy
      end

      rule { oncall_schedules_available & can?(:reporter_access) }.enable :read_incident_management_oncall_schedule
      rule { escalation_policies_available & can?(:reporter_access) }.enable :read_incident_management_escalation_policy

      rule { can?(:read_code) }.policy do
        enable :read_path_locks
      end

      rule { can?(:developer_access) }.policy do
        enable :admin_issue_board
        enable :admin_feature_flags_issue_links
        enable :read_project_audit_events
        enable :create_workspace
        enable :enable_continuous_vulnerability_scans
        enable :read_project_security_exclusions
        enable :read_security_settings
        enable :read_vulnerability_statistics
        enable :read_security_resource
        enable :read_vulnerability
        enable :update_secret_detection_validity_checks_status
        enable :read_ai_catalog_item_consumer
      end

      rule { can?(:push_code) }.policy do
        enable :create_path_lock
      end

      rule { planner_or_reporter_access & iterations_available }.policy do
        enable :create_iteration
        enable :admin_iteration
      end

      rule { custom_roles_allowed & (guest | admin) }.policy do
        enable :read_member_role
      end

      rule { can?(:read_project) & iterations_available }.enable :read_iteration

      rule { security_orchestration_policies_enabled & can?(:developer_access) }.policy do
        enable :read_security_orchestration_policies
      end

      rule { security_orchestration_policies_enabled & can?(:owner_access) }.policy do
        enable :update_security_orchestration_policy_project
      end

      rule { security_orchestration_policies_enabled & can?(:reporter_access) }.policy do
        enable :read_security_orchestration_policy_project
      end

      rule { security_orchestration_policies_enabled & auditor }.policy do
        enable :read_security_orchestration_policies
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
        enable :access_security_and_compliance
      end

      rule { ~security_dashboard_enabled }.policy do
        prevent :read_security_resource
        prevent :read_vulnerability
        prevent :admin_vulnerability
      end

      rule { security_scans_api_enabled & can?(:developer_access) }.policy do
        enable :access_security_scans_api
      end

      rule { coverage_fuzzing_enabled & can?(:developer_access) }.policy do
        enable :read_coverage_fuzzing
        enable :create_coverage_fuzzing_corpus
      end

      rule { on_demand_scans_enabled & can?(:developer_access) }.policy do
        enable :read_on_demand_dast_scan
        enable :create_on_demand_dast_scan
        enable :edit_on_demand_dast_scan
      end

      rule { on_demand_scans_enabled & security_policy_bot }.policy do
        enable :read_on_demand_dast_scan
        enable :create_on_demand_dast_scan
      end

      rule { security_dashboard_enabled & can?(:maintainer_access) }.policy do
        enable :admin_security_testing
      end

      rule { custom_role_enables_admin_security_testing }.policy do
        enable :admin_security_testing
        enable :configure_secret_detection_validity_checks
        enable :update_secret_detection_validity_checks_status
      end

      rule { security_dashboard_enabled & can?(:admin_security_testing) }.policy do
        enable :access_security_and_compliance
        enable :read_security_configuration
        enable :read_project_security_dashboard
        enable :read_security_resource
        enable :read_vulnerability
        # create scanner configuration
        enable :push_code
        enable :download_code
        enable :read_merge_request
        enable :create_merge_request_from
      end

      rule { secret_push_protection_available & can?(:admin_security_testing) }.policy do
        enable :read_secret_push_protection_info
        enable :enable_secret_push_protection
        enable :read_project_security_exclusions
      end

      rule { ~validity_checks_available }.policy do
        prevent :configure_secret_detection_validity_checks
      end

      rule { ~refresh_validity_checks_available }.policy do
        prevent :update_secret_detection_validity_checks_status
      end

      rule { container_scanning_for_registry_available & can?(:admin_security_testing) }.policy do
        enable :enable_container_scanning_for_registry
      end

      rule { coverage_fuzzing_enabled & can?(:admin_security_testing) }.policy do
        enable :read_coverage_fuzzing
        enable :create_coverage_fuzzing_corpus
      end

      rule { security_scans_api_enabled & can?(:admin_security_testing) }.policy do
        enable :access_security_scans_api
      end

      rule { on_demand_scans_enabled & can?(:admin_security_testing) }.policy do
        enable :read_on_demand_dast_scan
        enable :create_on_demand_dast_scan
        enable :edit_on_demand_dast_scan

        enable :read_runners # read runner tags when creating scan
        enable :create_pipeline # run a scan
      end

      rule { security_dashboard_enabled & security_policy_bot }.policy do
        enable :create_vulnerability_state_transition
      end

      # If licensed but not reporter+, prevent access
      rule { can?(:read_merge_request) & can?(:read_issue) & licensed_cycle_analytics_available }.policy do
        enable :read_cycle_analytics
      end

      # If licensed and reporter+, allow access
      rule { ((reporter | admin)) & licensed_cycle_analytics_available }.policy do
        enable :admin_value_stream
      end

      rule { can?(:read_merge_request) & can?(:read_pipeline) }.enable :read_merge_train

      rule { can?(:read_security_resource) }.policy do
        enable :read_project_security_dashboard
        enable :create_vulnerability_export
        enable :create_vulnerability_archive_export
        enable :admin_vulnerability_issue_link
        enable :admin_vulnerability_merge_request_link
        enable :admin_vulnerability_external_issue_link
      end

      rule { can?(:admin_vulnerability) }.policy do
        enable :read_vulnerability
        enable :create_vulnerability_feedback
        enable :destroy_vulnerability_feedback
        enable :update_vulnerability_feedback
        enable :create_vulnerability_state_transition
      end

      rule { can?(:read_vulnerability) }.policy do
        enable :read_vulnerability_feedback
        enable :read_vulnerability_scanner
        enable :read_vulnerability_representation_information
        enable :read_vulnerability_statistics
      end

      condition(:resolve_vulnerability_allowed) do
        next false unless @user

        ::Gitlab::Llm::FeatureAuthorizer.new(
          container: subject,
          feature_name: :resolve_vulnerability,
          user: @user
        ).allowed?
      end

      rule { can?(:read_security_resource) & resolve_vulnerability_allowed }.policy do
        enable :resolve_vulnerability_with_ai
      end

      rule { security_and_compliance_disabled }.policy do
        prevent :admin_vulnerability
        prevent :read_vulnerability
      end

      rule { security_bot }.policy do
        enable :push_code
        enable :create_merge_request_from
        enable :create_vulnerability_feedback
        enable :admin_merge_request
      end

      rule { issues_disabled }.policy do
        prevent :read_issue_analytics
      end

      rule { merge_requests_disabled }.policy do
        prevent :read_project_merge_request_analytics
      end

      rule { issues_disabled & merge_requests_disabled }.policy do
        prevent :read_iteration
        prevent :create_iteration
        prevent :update_iteration
        prevent :admin_iteration
        prevent :destroy_iteration
      end

      rule { dependency_scanning_enabled & can?(:download_code) }.enable :read_dependency

      rule { license_scanning_enabled & can?(:download_code) }.enable :read_licenses

      rule { can?(:read_licenses) }.enable :read_software_license_policy

      rule { repository_mirrors_enabled & ((mirror_available & can?(:admin_project)) | admin) }.enable :admin_mirror

      rule { can?(:maintainer_access) }.policy do
        enable :push_code_to_protected_branches
        enable :admin_path_locks
        enable :read_approvers
        enable :update_approvers
        enable :modify_approvers_rules
        enable :modify_merge_request_author_setting
        enable :modify_merge_request_committer_setting
        enable :modify_product_analytics_settings
        enable :admin_push_rules
        enable :manage_deploy_tokens
        enable :read_runner_usage
        enable :manage_project_security_exclusions
        enable :read_project_security_exclusions
        enable :manage_security_settings
        enable :configure_secret_detection_validity_checks
        enable :admin_vulnerability
        enable :admin_ai_catalog_item
        enable :admin_ai_catalog_item_consumer
      end

      rule { ~runner_performance_insights_available }.prevent :read_runner_usage

      rule { ~clickhouse_main_database_available }.prevent :read_runner_usage

      rule { license_scanning_enabled & can?(:maintainer_access) }.enable :admin_software_license_policy

      rule { oncall_schedules_available & can?(:maintainer_access) }.enable :admin_incident_management_oncall_schedule
      rule { escalation_policies_available & can?(:maintainer_access) }.enable :admin_incident_management_escalation_policy

      rule { auditor }.policy do
        enable :public_user_access
        prevent :request_access

        enable :read_build
        enable :read_environment
        enable :read_deployment
        enable :read_pages
        enable :read_project_audit_events
        enable :read_cluster
        enable :read_terraform_state
        enable :read_project_merge_request_analytics
        enable :read_approvers
        enable :read_on_demand_dast_scan

        enable :read_runners
        enable :read_project_security_exclusions
        enable :read_security_settings

        enable :access_security_and_compliance
        enable :read_security_resource
        enable :read_vulnerability
      end

      rule { auditor & ~guest & private_project }.policy do
        prevent :fork_project
        prevent :create_merge_request_in
      end

      rule { auditor & oncall_schedules_available }.policy do
        enable :read_incident_management_oncall_schedule
      end

      rule { auditor & escalation_policies_available }.policy do
        enable :read_incident_management_escalation_policy
      end

      rule { auditor & ~monitor_disabled }.policy do
        enable :read_alert_management_alert
      end

      rule { auditor & ~developer }.policy do
        prevent :admin_vulnerability_issue_link
        prevent :admin_vulnerability_external_issue_link
        prevent :admin_vulnerability_merge_request_link
        prevent :admin_vulnerability
      end

      rule { auditor & ~guest }.policy do
        prevent :create_project
        prevent :create_issue
        prevent :create_note
        prevent :upload_file
        prevent :admin_issue_link
      end

      rule { ~can?(:push_code) }.prevent :push_code_to_protected_branches

      rule { can?(:admin_push_rules) }.policy do
        enable :change_push_rules

        enable :read_commit_committer_check
        enable :change_commit_committer_check

        enable :read_commit_committer_name_check
        enable :change_commit_committer_name_check

        enable :read_reject_unsigned_commits
        enable :change_reject_unsigned_commits

        enable :read_reject_non_dco_commits
        enable :change_reject_non_dco_commits
      end

      rule { ~push_rules_available }.policy do
        prevent :change_push_rules
      end

      rule { ~commit_committer_check_available }.policy do
        prevent :read_commit_committer_check
        prevent :change_commit_committer_check
      end

      rule { ~commit_committer_name_check_available }.policy do
        prevent :read_commit_committer_name_check
        prevent :change_commit_committer_name_check
      end

      rule { ~reject_unsigned_commits_available }.policy do
        prevent :read_reject_unsigned_commits
        prevent :change_reject_unsigned_commits
      end

      rule { ~reject_non_dco_commits_available }.policy do
        prevent :read_reject_non_dco_commits
        prevent :change_reject_non_dco_commits
      end

      rule { owner | reporter | internal_access | public_project }.enable :build_read_project

      rule { ~admin & owner & owner_cannot_destroy_project }.prevent :remove_project

      rule { user_banned_from_namespace }.prevent_all

      condition(:needs_new_sso_session) do
        ::Gitlab::Auth::GroupSaml::SsoEnforcer.access_restricted?(user: @user, resource: subject)
      end

      condition(:duo_code_review_bot) do
        @user.duo_code_review_bot?
      end

      condition(:ip_enforcement_prevents_access, scope: :subject) do
        !::Gitlab::IpRestriction::Enforcer.new(subject.group).allows_current_ip? if subject.group
      end

      rule { custom_role_enables_archive_project }.policy do
        enable :archive_project
      end

      rule { custom_role_enables_remove_project }.policy do
        enable :remove_project
      end

      rule { can?(:admin_project) | can?(:archive_project) | can?(:remove_project) | can?(:admin_compliance_framework) }.policy do
        enable :view_edit_page
      end

      rule { needs_new_sso_session }.policy do
        prevent :read_project
      end

      rule { ip_enforcement_prevents_access & ~admin & ~auditor }.policy do
        prevent_all
      end

      rule { locked_approvers_rules }.policy do
        prevent :modify_approvers_rules
      end

      rule { locked_merge_request_author_setting }.policy do
        prevent :modify_merge_request_author_setting
      end

      rule { locked_merge_request_committer_setting }.policy do
        prevent :modify_merge_request_committer_setting
      end

      rule { issue_analytics_enabled }.enable :read_issue_analytics

      rule { can?(:read_merge_request) & code_review_analytics_enabled }.enable :read_code_review_analytics

      rule { private_project & planner }.prevent :read_code_review_analytics

      rule { (admin | reporter) & dora4_analytics_available }
        .enable :read_dora4_analytics

      rule { (admin | reporter) & project_merge_request_analytics_available }
        .enable :read_project_merge_request_analytics

      condition(:assigned_to_duo_enterprise) do
        @user.assigned_to_duo_enterprise?(@subject)
      end

      condition(:assigned_to_duo_pro) do
        @user.assigned_to_duo_pro?(@subject)
      end

      condition(:duo_usage_analytics_enabled) do
        ::Feature.enabled?(:duo_usage_dashboard, @subject.root_ancestor) && @user.assigned_to_duo_add_ons?(@subject)
      end

      condition(:amazon_q_enabled) do
        ::Ai::AmazonQ.enabled?
      end

      rule { can?(:read_customizable_dashboards) & (amazon_q_enabled | assigned_to_duo_pro) }.enable :read_pro_ai_analytics
      rule { can?(:read_customizable_dashboards) & (amazon_q_enabled | assigned_to_duo_enterprise) }.enable :read_enterprise_ai_analytics

      rule { can?(:read_customizable_dashboards) & duo_usage_analytics_enabled }.enable :read_duo_usage_analytics

      rule { combined_project_analytics_dashboards_enabled }.enable :read_combined_project_analytics_dashboards

      rule { combined_project_analytics_dashboards_enabled & can?(:read_cycle_analytics) }.enable :read_project_level_value_stream_dashboard_overview_counts

      rule { can?(:read_project) & requirements_available }.enable :read_requirement

      rule { requirements_available & (planner | reporter | admin) }.policy do
        enable :create_requirement
        enable :create_requirement_test_report
        enable :admin_requirement
        enable :update_requirement
        enable :import_requirements
        enable :export_requirements
      end

      rule { requirements_available & (owner | admin) }.enable :destroy_requirement

      rule { quality_management_available & planner_or_reporter_access & can?(:create_issue) }.policy do
        enable :create_test_case
      end

      condition(:can_admin_compliance_framework_in_group) do
        in_group? && can?(:admin_compliance_framework, @subject.group)
      end

      rule { can_admin_compliance_framework_in_group }.enable :admin_compliance_framework

      rule { project_epics_available & planner_or_reporter_access & can?(:create_issue) }.policy do
        enable :create_epic
      end

      rule { (admin | owner | auditor) & project_level_compliance_dashboard_enabled }.policy do
        enable :read_compliance_dashboard
      end

      rule { (admin | owner | auditor) & project_level_compliance_adherence_report_enabled }.policy do
        enable :read_compliance_adherence_report
      end

      rule { (admin | owner | auditor) & project_level_compliance_violations_report_enabled }.policy do
        enable :read_compliance_violations_report
      end

      rule { status_page_available & can?(:owner_access) }.enable :mark_issue_for_publication
      rule { status_page_available & can?(:developer_access) }.enable :publish_status_page

      rule { google_cloud_support_available & can?(:maintainer_access) }.policy do
        enable :read_runner_cloud_provisioning_info
        enable :read_runner_gke_provisioning_info
        enable :provision_cloud_runner
        enable :provision_gke_runner
      end
      rule { google_cloud_support_available & can?(:reporter_access) }.enable :read_google_cloud_artifact_registry
      rule { google_cloud_support_available & can?(:maintainer_access) }.enable :admin_google_cloud_artifact_registry

      rule { hidden }.policy do
        prevent :read_code
        prevent :download_code
        prevent :build_download_code
      end

      rule { read_only }.policy do
        prevent(*readonly_abilities)

        readonly_features.each do |feature|
          prevent :"create_#{feature}"
          prevent :"update_#{feature}"
          prevent :"admin_#{feature}"
        end
      end

      rule { auditor | can?(:developer_access) }.enable :add_project_to_instance_security_dashboard

      rule { (admin | maintainer) & group_merge_request_approval_settings_enabled }.policy do
        enable :admin_merge_request_approval_settings
      end

      rule { custom_role_enables_read_code }.enable :read_code

      rule { custom_role_enables_read_vulnerability }.policy do
        enable :access_security_and_compliance
        enable :read_vulnerability
        enable :read_security_resource
        enable :create_vulnerability_export
        enable :create_vulnerability_archive_export
      end

      rule { custom_role_enables_admin_merge_request }.policy do
        enable :create_merge_request_from
        enable :read_merge_request
        enable :admin_merge_request
        enable :download_code # required to negate https://gitlab.com/gitlab-org/gitlab/-/blob/3061d30d9b3d6d4c4dd5abe68bc1e4a8a93c7966/app/policies/project_policy.rb#L603-607
      end

      rule { custom_role_enables_admin_terraform_state }.policy do
        enable :read_terraform_state
        enable :admin_terraform_state
      end

      rule { custom_role_enables_admin_vulnerability }.policy do
        enable :admin_vulnerability
        enable :read_vulnerability
      end

      rule { custom_role_enables_read_dependency & dependency_scanning_enabled }.policy do
        enable :access_security_and_compliance
        enable :read_dependency
      end

      rule { custom_role_enables_admin_compliance_framework }.policy do
        enable :admin_compliance_framework
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

      rule { ~project_level_compliance_dashboard_enabled }.policy do
        prevent :read_compliance_dashboard
      end

      rule { ~project_level_compliance_adherence_report_enabled }.policy do
        prevent :read_compliance_adherence_report
      end

      rule { ~project_level_compliance_violations_report_enabled }.policy do
        prevent :read_compliance_violations_report
      end

      rule { custom_role_enables_manage_deploy_tokens }.policy do
        enable :manage_deploy_tokens
        enable :read_deploy_token
        enable :create_deploy_token
        enable :destroy_deploy_token
      end

      rule { custom_role_enables_admin_protected_branch }.policy do
        enable :read_protected_branch
        enable :create_protected_branch
        enable :update_protected_branch
        enable :destroy_protected_branch
        enable :admin_protected_branch
      end

      rule { can?(:create_issue) & okrs_enabled }.policy do
        enable :create_objective
        enable :create_key_result
      end

      rule { suggested_reviewers_bot & suggested_reviewers_available & resource_access_token_feature_available & resource_access_token_creation_allowed }.policy do
        enable :admin_project_member
        enable :create_resource_access_tokens
      end

      rule { custom_role_enables_manage_project_access_tokens & resource_access_token_feature_available & resource_access_token_creation_allowed }.policy do
        enable :read_resource_access_tokens
        enable :create_resource_access_tokens
        enable :destroy_resource_access_tokens
        enable :manage_resource_access_tokens
      end

      rule { custom_role_enables_manage_merge_request_settings }.policy do
        enable :manage_merge_request_settings
        enable :edit_approval_rule
        enable :modify_approvers_rules
        enable :modify_merge_request_author_setting
        enable :modify_merge_request_committer_setting
      end

      rule { can?(:manage_merge_request_settings) & target_branch_rules_available }.policy do
        enable :admin_target_branch_rule
      end

      rule { can?(:manage_merge_request_settings) & group_merge_request_approval_settings_enabled }.policy do
        enable :admin_merge_request_approval_settings
      end

      rule { security_policy_bot & project_allowed_for_job_token_by_scope }.policy do
        enable :create_pipeline
        enable :create_bot_pipeline
        enable :build_download_code
      end

      rule do
        summarize_new_merge_request_enabled & can?(:create_merge_request_in)
      end.enable :access_summarize_new_merge_request

      rule do
        generate_description_enabled & can?(:create_issue)
      end.enable :generate_description

      rule do
        summarize_notes_allowed & can?(:read_issue)
      end.enable :summarize_comments

      rule { target_branch_rules_available & maintainer }.policy do
        enable :admin_target_branch_rule
      end

      rule { target_branch_rules_available }.policy do
        enable :read_target_branch_rule
      end

      rule do
        (maintainer | owner | admin) & pages_multiple_versions_available
      end.enable :pages_multiple_versions

      rule { can?(:reporter_access) & observability_enabled }.policy do
        enable :read_observability
      end

      rule { can?(:developer_access) & observability_enabled }.policy do
        enable :write_observability
      end

      rule { ci_cancellation_maintainers_only & ~can?(:maintainer_access) }.policy do
        prevent :cancel_pipeline
        prevent :cancel_build
      end

      rule { ci_cancellation_no_one }.policy do
        prevent :cancel_pipeline
        prevent :cancel_build
      end

      rule { guest | admin }.enable :read_limit_alert

      rule { guest & agent_registry_enabled }.policy do
        enable :read_ai_agents
      end

      rule { reporter & agent_registry_enabled }.policy do
        enable :write_ai_agents
      end

      rule { can?(:read_project) & chat_allowed_for_parent_group & chat_available_for_user & duo_features_enabled }.policy do
        enable :access_duo_chat
      end

      condition(:model_pinned_for_duo_chat) do
        ::Feature.enabled?(:ai_model_switching, @subject.root_ancestor) && Ai::ModelSelection::NamespaceFeatureSetting.any_non_default_for_duo_chat?(@subject.root_ancestor.id)
      end

      condition(:can_use_agentic_chat) do
        can?(:access_duo_agentic_chat, subject.root_ancestor)
      end

      rule { can_use_agentic_chat & duo_features_enabled & ~model_pinned_for_duo_chat & ~amazon_q_enabled }.policy do
        enable :access_duo_agentic_chat
      end

      rule { can?(:read_project) & duo_features_enabled }.enable :access_duo_features

      desc "Project has saved replies support"
      condition(:supports_saved_replies) do
        @subject.supports_saved_replies?
      end

      rule { supports_saved_replies & guest }.enable :read_saved_replies

      rule { supports_saved_replies & developer }.policy do
        enable :create_saved_replies
        enable :destroy_saved_replies
        enable :update_saved_replies
      end

      condition(:secret_push_protection_available) do
        @subject.licensed_feature_available?(:secret_push_protection)
      end

      rule { secret_push_protection_available & can?(:maintainer_access) }.policy do
        enable :enable_secret_push_protection
      end

      condition(:validity_checks_available, scope: :subject) do
        ::Feature.enabled?(:validity_checks, @subject) &&
          @subject.licensed_feature_available?(:secret_detection_validity_checks)
      end

      condition(:refresh_validity_checks_available, scope: :subject) do
        ::Feature.enabled?(:validity_checks, @subject) &&
          @subject.licensed_feature_available?(:secret_detection_validity_checks) &&
          ::Feature.enabled?(:secret_detection_validity_checks_refresh_token, @subject)
      end

      condition(:container_scanning_for_registry_available) do
        @subject.licensed_feature_available?(:container_scanning_for_registry)
      end
      rule { container_scanning_for_registry_available & can?(:maintainer_access) }.policy do
        enable :enable_container_scanning_for_registry
      end

      rule { secret_push_protection_available & can?(:developer_access) }.policy do
        enable :read_secret_push_protection_info
      end

      condition(:duo_workflow_enabled) do
        ::Feature.enabled?(:duo_workflow, @user)
      end

      with_scope :subject
      condition(:duo_workflow_available) do
        @subject.duo_features_enabled &&
          ::Gitlab::Llm::StageCheck.available?(@subject, :duo_workflow) &&
          @user&.allowed_to_use?(:duo_agent_platform)
      end

      rule { duo_workflow_enabled & duo_workflow_available & can?(:developer_access) }.policy do
        enable :duo_workflow
      end

      rule { custom_role_enables_admin_web_hook }.policy do
        enable :read_web_hook
        enable :admin_web_hook
      end

      with_scope :subject
      condition(:runner_performance_insights_available) do
        @subject.group&.licensed_feature_available?(:runner_performance_insights_for_namespace)
      end

      with_scope :global
      condition(:clickhouse_main_database_available) do
        ::Gitlab::ClickHouse.configured?
      end

      rule { can?(:owner_access) }.policy do
        enable :admin_project_secrets_manager
      end

      condition(:container_registry_immutable_tag_rules_available, scope: :subject) do
        @subject.feature_available?(:container_registry_immutable_tag_rules)
      end

      rule { can?(:owner_access) & container_registry_immutable_tag_rules_available }.policy do
        enable :create_container_registry_protection_immutable_tag_rule
      end

      condition(:secrets_manager_enabled) do
        ::Feature.enabled?(:secrets_manager, @subject)
      end

      condition(:secrets_manager_active) do
        @subject&.secrets_manager&.active?
      end

      rule { can?(:reporter_access) & secrets_manager_enabled }.policy do
        enable :read_project_secrets_manager_status
      end

      rule { can?(:reporter_access) & secrets_manager_enabled & secrets_manager_active }.policy do
        enable :read_project_secrets
        enable :create_project_secrets
        enable :update_project_secrets
        enable :delete_project_secrets
      end

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

      rule { duo_workflow_token & ~duo_features_enabled }.prevent_all

      condition(:description_composer_enabled) do
        subject.project_setting.duo_features_enabled? &&
          ::Feature.enabled?(:mr_description_composer, @user) &&
          ::Gitlab::Llm::FeatureAuthorizer.new(
            container: @subject,
            feature_name: :description_composer,
            user: @user,
            licensed_feature: :description_composer
          ).allowed?
      end

      rule do
        description_composer_enabled & can?(:read_merge_request)
      end.enable :access_description_composer

      rule { ~ai_catalog_enabled }.policy do
        prevent :admin_ai_catalog_item
        prevent :admin_ai_catalog_item_consumer
        prevent :read_ai_catalog_item_consumer
      end

      rule { container_registry_disabled }.policy do
        prevent :create_container_registry_protection_immutable_tag_rule
      end
    end

    override :lookup_access_level!
    def lookup_access_level!
      return ::Gitlab::Access::NO_ACCESS if needs_new_sso_session?
      return ::Gitlab::Access::REPORTER if security_bot?
      return ::Gitlab::Access::DEVELOPER if duo_code_review_bot?

      super
    end

    # Available in Core for self-managed but only paid for .com to prevent abuse
    override :resource_access_token_create_feature_available?
    def resource_access_token_create_feature_available?
      return false unless resource_access_token_feature_available?
      return super unless ::Gitlab.com?

      namespace = project.namespace
      namespace.licensed_feature_available?(:resource_access_token)
    end

    override :resource_access_token_feature_available?
    def resource_access_token_feature_available?
      return false if ::Gitlab::CurrentSettings.personal_access_tokens_disabled?

      super
    end

    def in_group?
      project&.namespace&.group_namespace?
    end

    def custom_role_ability(user, subject)
      strong_memoize_with(:custom_role_ability, user, subject) do
        ::Authz::CustomAbility.new(user, subject)
      end
    end
  end
end
