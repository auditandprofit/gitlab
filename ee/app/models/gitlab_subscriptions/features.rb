# frozen_string_literal: true

# All GitLab features that are available after purchasing a GitLab subscription
# either SaaS or self-managed.
# This class defines methods to check feature availability and their relation
# to GitLab plans.
module GitlabSubscriptions
  class Features
    # Global features that cannot be restricted to only a subset of projects or namespaces.
    # Use `License.feature_available?(:feature)` to check if these features are available.
    # For all other features, use `project.feature_available?` or `namespace.feature_available?` when possible.
    GLOBAL_FEATURES = %i[
      admin_audit_log
      amazon_q
      auditor_user
      custom_file_templates
      custom_project_templates
      db_load_balancing
      default_branch_protection_restriction_in_groups
      elastic_search
      enterprise_templates
      extended_audit_events
      external_authorization_service_api_management
      geo
      git_abuse_rate_limit
      instance_level_scim
      integrations_allow_list
      ldap_group_sync
      ldap_group_sync_filter
      multiple_ldap_servers
      object_storage
      pages_size_limit
      password_complexity
      project_aliases
      repository_size_limit
      required_ci_templates
      runner_maintenance_note
      runner_performance_insights
      runner_upgrade_management
      seat_link
      seat_usage_quotas
      pipelines_usage_quotas
      transfer_usage_quotas
      product_analytics_usage_quotas
      zoekt_code_search
      disable_private_profiles
      observability_alerts
    ].freeze

    STARTER_FEATURES = %i[
      audit_events
      blocked_issues
      blocked_work_items
      board_iteration_lists
      code_owners
      code_review_analytics
      full_codequality_report
      group_activity_analytics
      group_bulk_edit
      issuable_default_templates
      issue_weights
      iterations
      ldap_group_sync
      merge_request_approvers
      milestone_charts
      multiple_issue_assignees
      multiple_ldap_servers
      multiple_merge_request_assignees
      multiple_merge_request_reviewers
      project_merge_request_analytics
      protected_refs_for_users
      push_rules
      resource_access_token
      seat_link
      seat_usage_quotas
      pipelines_usage_quotas
      transfer_usage_quotas
      product_analytics_usage_quotas
      wip_limits
      zoekt_code_search
      seat_control
    ].freeze

    PREMIUM_FEATURES = %i[
      ai_chat
      ai_workflows
      admin_audit_log
      agent_managed_resources
      agentic_chat
      auditor_user
      blocking_merge_requests
      board_assignee_lists
      board_milestone_lists
      ci_secrets_management
      ci_pipeline_cancellation_restrictions
      cluster_agents_ci_impersonation
      cluster_agents_user_impersonation
      cluster_deployments
      code_owner_approval_required
      code_suggestions
      combined_project_analytics_dashboards
      commit_committer_check
      commit_committer_name_check
      compliance_framework
      custom_compliance_frameworks
      custom_fields
      custom_file_templates
      custom_project_templates
      cycle_analytics_for_groups
      cycle_analytics_for_projects
      db_load_balancing
      default_branch_protection_restriction_in_groups
      default_project_deletion_protection
      delete_unconfirmed_users
      dependency_proxy_for_packages
      disable_extensions_marketplace_for_enterprise_users
      disable_name_update_for_users
      disable_personal_access_tokens
      domain_verification
      epic_colors
      epics
      extended_audit_events
      external_authorization_service_api_management
      feature_flags_code_references
      file_locks
      geo
      generic_alert_fingerprinting
      git_two_factor_enforcement
      group_allowed_email_domains
      group_coverage_reports
      group_forking_protection
      group_level_analytics_dashboard
      group_level_compliance_dashboard
      group_milestone_project_releases
      group_project_templates
      group_repository_analytics
      group_saml
      group_scoped_ci_variables
      ide_schema_config
      incident_metric_upload
      instance_level_scim
      jira_issues_integration
      ldap_group_sync_filter
      linked_items_epics
      merge_request_performance_metrics
      admin_merge_request_approvers_rules
      merge_trains
      metrics_reports
      multiple_alert_http_integrations
      multiple_approval_rules
      multiple_group_issue_boards
      object_storage
      microsoft_group_sync
      operations_dashboard
      package_forwarding
      packages_virtual_registry
      pages_size_limit
      pages_multiple_versions
      productivity_analytics
      project_aliases
      project_level_analytics_dashboard
      protected_environments
      reject_non_dco_commits
      reject_unsigned_commits
      related_epics
      remote_development
      saml_group_sync
      service_accounts
      scoped_labels
      smartcard_auth
      ssh_certificates
      swimlanes
      target_branch_rules
      troubleshoot_job
      type_of_work_analytics
      minimal_access_role
      unprotection_restrictions
      ci_project_subscriptions
      incident_timeline_view
      oncall_schedules
      escalation_policies
      zentao_issues_integration
      coverage_check_approval_rule
      issuable_resource_links
      group_protected_branches
      group_level_merge_checks_setting
      oidc_client_groups_claim
      disable_deleting_account_for_users
      disable_private_profiles
      group_saved_replies
      requested_changes_block_merge_request
      project_saved_replies
      default_roles_assignees
      ci_component_usages_in_projects
      branch_rule_squash_options
      work_item_status
      glab_ask_git_command
      generate_commit_message
      summarize_new_merge_request
      summarize_review
      generate_description
      summarize_comments
      review_merge_request
      board_status_lists
      disable_invite_members
      self_hosted_models
    ].freeze

    ULTIMATE_FEATURES = %i[
      ai_agents
      ai_config_chat
      ai_features
      amazon_q
      api_discovery
      api_fuzzing
      auto_rollback
      cluster_receptive_agents
      cluster_image_scanning
      external_status_checks
      compliance_pipeline_configuration
      container_registry_immutable_tag_rules
      container_scanning
      credentials_inventory
      custom_roles
      dast
      dependency_scanning
      dora4_analytics
      description_composer
      enterprise_templates
      environment_alerts
      evaluate_group_level_compliance_pipeline
      explain_code
      external_audit_events
      experimental_features
      generate_test_file
      git_abuse_rate_limit
      group_ci_cd_analytics
      group_level_compliance_adherence_report
      group_level_compliance_violations_report
      project_level_compliance_dashboard
      project_level_compliance_adherence_report
      project_level_compliance_violations_report
      incident_management
      inline_codequality
      insights
      integrations_allow_list
      issuable_health_status
      issues_completed_analytics
      jira_vulnerabilities_integration
      jira_issue_association_enforcement
      kubernetes_cluster_vulnerabilities
      license_scanning
      native_secrets_management
      okrs
      personal_access_token_expiration_policy
      secret_push_protection
      product_analytics
      project_quality_summary
      quality_management
      release_evidence_test_artifacts
      report_approver_rules
      required_ci_templates
      requirements
      runner_maintenance_note
      runner_maintenance_note_for_namespace
      runner_performance_insights
      runner_performance_insights_for_namespace
      runner_upgrade_management
      runner_upgrade_management_for_namespace
      sast
      sast_advanced
      sast_iac
      sast_custom_rulesets
      sast_fp_reduction
      secret_detection
      security_attributes
      security_configuration_in_ui
      security_dashboard
      security_inventory
      security_on_demand_scans
      security_orchestration_policies
      security_training
      ssh_key_expiration_policy
      summarize_mr_changes
      stale_runner_cleanup_for_namespace
      status_page
      suggested_reviewers
      subepics
      observability
      unique_project_download_limit
      vulnerability_finding_signatures
      container_scanning_for_registry
      secret_detection_validity_checks
      security_exclusions
      security_scans_api
      observability_alerts
      measure_comment_temperature
    ].freeze

    STARTER_FEATURES_WITH_USAGE_PING = %i[
      description_diffs
      send_emails_from_admin_area
      repository_size_limit
      maintenance_mode
      scoped_issue_board
      contribution_analytics
      group_webhooks
      member_lock
      elastic_search
      repository_mirrors
    ].freeze

    # Features defined in this list will be available in Premium license OR by enabling usage ping setting
    PREMIUM_FEATURES_WITH_USAGE_PING = %i[
      group_ip_restriction
      issues_analytics
      password_complexity
      group_wikis
      email_additional_text
      custom_file_templates_for_namespace
      incident_sla
      export_user_permissions
      cross_project_pipelines
      feature_flags_related_issues
      merge_pipelines
      ci_cd_projects
      github_integration
    ].freeze

    # Features defined in this list will be available in Ultimate license OR by enabling usage ping setting
    ULTIMATE_FEATURES_WITH_USAGE_PING = %i[
      coverage_fuzzing
      devops_adoption
      group_level_devops_adoption
      instance_level_devops_adoption
    ].freeze

    ALL_STARTER_FEATURES  = STARTER_FEATURES + STARTER_FEATURES_WITH_USAGE_PING
    ALL_PREMIUM_FEATURES  = ALL_STARTER_FEATURES + PREMIUM_FEATURES + PREMIUM_FEATURES_WITH_USAGE_PING
    ALL_ULTIMATE_FEATURES = ALL_PREMIUM_FEATURES + ULTIMATE_FEATURES + ULTIMATE_FEATURES_WITH_USAGE_PING
    ALL_FEATURES = ALL_ULTIMATE_FEATURES

    FEATURES_WITH_USAGE_PING = STARTER_FEATURES_WITH_USAGE_PING + PREMIUM_FEATURES_WITH_USAGE_PING + ULTIMATE_FEATURES_WITH_USAGE_PING

    FEATURES_BY_PLAN = {
      License::STARTER_PLAN => ALL_STARTER_FEATURES,
      License::PREMIUM_PLAN => ALL_PREMIUM_FEATURES,
      License::ULTIMATE_PLAN => ALL_ULTIMATE_FEATURES
    }.freeze

    LICENSE_PLANS_TO_SAAS_PLANS = {
      License::STARTER_PLAN => [::Plan::BRONZE],
      License::PREMIUM_PLAN => [::Plan::SILVER, ::Plan::PREMIUM, ::Plan::PREMIUM_TRIAL],
      License::ULTIMATE_PLAN => [
        ::Plan::GOLD,
        ::Plan::ULTIMATE,
        ::Plan::ULTIMATE_TRIAL,
        ::Plan::ULTIMATE_TRIAL_PAID_CUSTOMER,
        ::Plan::OPEN_SOURCE
      ]
    }.freeze

    PLANS_BY_FEATURE = FEATURES_BY_PLAN.each_with_object({}) do |(plan, features), hash|
      features.each do |feature|
        hash[feature] ||= []
        hash[feature] << plan
      end
    end.freeze

    # Add on codes that may occur in legacy licenses that don't have a plan yet.
    FEATURES_FOR_ADD_ONS = {
      'GitLab_Auditor_User' => :auditor_user,
      'GitLab_FileLocks' => :file_locks,
      'GitLab_Geo' => :geo
    }.freeze

    class << self
      def features(plan:, add_ons:)
        (for_plan(plan) + for_add_ons(add_ons)).to_set
      end

      def global?(feature)
        GLOBAL_FEATURES.include?(feature)
      end

      def usage_ping_feature?(feature)
        features_with_usage_ping.include?(feature)
      end

      def plans_with_feature(feature)
        if global?(feature)
          raise ArgumentError, "Use `License.feature_available?` for features that cannot be restricted to only a subset of projects or namespaces"
        end

        PLANS_BY_FEATURE.fetch(feature, [])
      end

      def saas_plans_with_feature(feature)
        LICENSE_PLANS_TO_SAAS_PLANS.values_at(*plans_with_feature(feature)).flatten
      end

      def features_with_usage_ping
        return FEATURES_WITH_USAGE_PING if Gitlab::CurrentSettings.usage_ping_features_enabled?

        []
      end

      private

      def for_plan(plan)
        FEATURES_BY_PLAN.fetch(plan, [])
      end

      def for_add_ons(add_ons)
        add_ons.map { |name, count| FEATURES_FOR_ADD_ONS[name] if count.to_i > 0 }.compact
      end
    end
  end
end

GitlabSubscriptions::Features.prepend_mod
