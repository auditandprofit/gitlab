# frozen_string_literal: true

module EE
  module SecurityComplianceCenterHelper
    def compliance_center_app_data(container)
      return unless container

      group = container.is_a?(Group) ? container : container.group
      adherence_report = can?(current_user, :read_compliance_adherence_report, container)
      violations_report = can?(current_user, :read_compliance_violations_report, container)
      compliance_status_report_export_path =
        group_security_compliance_dashboard_exports_compliance_status_report_path(group, format: :csv)

      if container.is_a?(Group)
        {
          feature_frameworks_report_enabled: true.to_s,
          feature_security_policies_enabled: can?(current_user, :read_security_orchestration_policies, group).to_s,
          framework_import_url: import_group_security_compliance_frameworks_path(group),
          violations_csv_export_path: violations_report && group_security_compliance_violation_reports_path(
            group, format: :csv),
          project_frameworks_csv_export_path: group_security_compliance_project_framework_reports_path(group,
            format: :csv),
          adherences_csv_export_path: adherence_report && group_security_compliance_standards_adherence_reports_path(
            group, format: :csv),
          frameworks_csv_export_path: group_security_compliance_framework_reports_path(group, format: :csv),
          merge_commits_csv_export_path: group_security_merge_commit_reports_path(group),
          compliance_status_report_export_path: compliance_status_report_export_path,
          pipeline_configuration_full_path_enabled: can?(current_user, :admin_compliance_pipeline_configuration,
            group).to_s,
          pipeline_configuration_enabled: group.licensed_feature_available?(:compliance_pipeline_configuration).to_s,

          migrate_pipeline_to_policy_path: help_page_path('user/compliance/compliance_pipelines.md',
            anchor: 'pipeline-execution-policies-migration'),
          pipeline_execution_policy_path: new_group_security_policy_url(group, type: :pipeline_execution_policy),
          group_security_policies_path: group_security_policies_path(group),
          disable_scan_policy_update: !can_modify_security_policy?(group).to_s
        }.merge(general_app_data(container))
      else
        general_app_data(container)
      end
    end

    private

    def general_app_data(container)
      project = container.is_a?(Project) ? container : nil
      group = container.is_a?(Group) ? container : container.group

      can_admin_compliance_frameworks = can?(current_user, :admin_compliance_framework, container)
      adherence_report = can?(current_user, :read_compliance_adherence_report, container)
      violations_report = can?(current_user, :read_compliance_violations_report, container)
      can_access_root_ancestor_compliance_center = can?(current_user, :read_compliance_dashboard, group.root_ancestor)

      {
        base_path: base_path(container),
        project_id: project&.id,
        project_path: project&.full_path,
        project_name: project&.name,
        group_path: group.full_path,
        group_compliance_center_path: group_security_compliance_dashboard_path(group, vueroute: 'projects'),
        group_name: group.name,
        root_ancestor_path: group.root_ancestor.full_path,
        root_ancestor_name: group.root_ancestor.name,
        root_ancestor_compliance_center_path: group_security_compliance_dashboard_path(group.root_ancestor,
          vueroute: 'frameworks'),

        can_access_root_ancestor_compliance_center: can_access_root_ancestor_compliance_center.to_s,
        feature_adherence_report_enabled: adherence_report.to_s,

        feature_violations_report_enabled: violations_report.to_s,
        violations_v2_enabled: ::Feature.enabled?(:compliance_violations_report, group).to_s,
        active_compliance_frameworks: group.active_compliance_frameworks?.to_s,
        feature_projects_report_enabled: true.to_s,
        can_admin_compliance_frameworks: can_admin_compliance_frameworks.to_s,
        policy_display_limit: 10
      }
    end

    def base_path(container)
      if container.is_a?(Group)
        group_security_compliance_dashboard_path(container)
      else
        project_security_compliance_dashboard_path(container)
      end
    end
  end
end
