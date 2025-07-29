# frozen_string_literal: true

module EE
  module Projects
    module Settings
      module BranchRulesHelper
        def branch_rules_data(project)
          show_status_checks = project.licensed_feature_available?(:external_status_checks)
          show_approvers = project.licensed_feature_available?(:merge_request_approvers)
          show_code_owners = project.licensed_feature_available?(:code_owner_approval_required)
          show_enterprise_access_levels = project.licensed_feature_available?(:protected_refs_for_users)
          {
            project_path: project.full_path,
            protected_branches_path: project_settings_repository_path(project,
              anchor: 'js-protected-branches-settings'),
            branch_rules_path: project_settings_repository_path(project, anchor: 'branch-rules'),
            approval_rules_path: project_settings_merge_requests_path(project,
              anchor: 'js-merge-request-approval-settings'),
            status_checks_path: project_settings_merge_requests_path(project, anchor: 'js-merge-request-settings'),
            branches_path: project_branches_path(project),
            show_status_checks: show_status_checks.to_s,
            show_approvers: show_approvers.to_s,
            show_code_owners: show_code_owners.to_s,
            show_enterprise_access_levels: show_enterprise_access_levels.to_s,
            project_id: project.id,
            rules_path: expose_path(api_v4_projects_approval_rules_path(id: project.id)),
            can_edit: can?(current_user, :modify_approvers_rules, project).to_s,
            allow_multi_rule: project.multiple_approval_rules_available?.to_s,
            can_admin_protected_branches: can?(current_user, :admin_protected_branch, project).to_s
          }
        end
      end
    end
  end
end
