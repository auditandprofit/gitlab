# frozen_string_literal: true

module Projects
  class ProjectSettingChangesAuditor < ::AuditEvents::BaseChangesAuditor
    def initialize(current_user, project_setting, project)
      @project = project

      super(current_user, project_setting)
    end

    def execute
      return if model.blank?

      if should_audit? :allow_merge_on_skipped_pipeline
        audit_changes(:allow_merge_on_skipped_pipeline,
          as: 'allow_merge_on_skipped_pipeline', entity: @project,
          model: model, event_type: 'allow_merge_on_skipped_pipeline_updated')
      end

      audit_squash_option
      audit_changes(
        :merge_commit_template,
        as: 'merge_commit_template',
        entity: @project,
        model: model,
        event_type: 'merge_commit_template_updated'
      )
      audit_changes(
        :squash_commit_template,
        as: 'squash_commit_template',
        entity: @project,
        model: model,
        event_type: 'squash_commit_template_updated'
      )
      audit_changes(
        :duo_features_enabled,
        as: 'duo_features_enabled',
        entity: @project,
        model: model,
        event_type: 'duo_features_enabled_updated'
      )
      audit_changes(
        :selective_code_owner_removals,
        as: 'selective_code_owner_removals',
        entity: @project,
        model: model,
        event_type: 'selective_code_owner_removals_updated'
      )
      audit_changes(
        :require_reauthentication_to_approve,
        as: 'require_reauthentication_to_approve',
        entity: @project,
        model: model,
        event_type: 'require_reauthentication_to_approve_updated'
      )
    end

    def attributes_from_auditable_model(column)
      {
        from: model.previous_changes[column].first,
        to: model.previous_changes[column].last,
        target_details: @project.full_path
      }
    end

    private

    def audit_squash_option
      return unless audit_required? :squash_option

      squash_option_message = format(_("Changed squash option to %{squash_option}"),
        squash_option: model.human_squash_option)
      audit_context = {
        author: @current_user,
        scope: @project,
        target: @project,
        message: squash_option_message,
        name: 'squash_option_updated'
      }
      ::Gitlab::Audit::Auditor.audit(audit_context)
    end
  end
end
