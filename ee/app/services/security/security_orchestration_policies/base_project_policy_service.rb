# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class BaseProjectPolicyService
      include Gitlab::Utils::StrongMemoize
      include Gitlab::InternalEventsTracking

      def initialize(project:, security_policy:)
        @project = project
        @security_policy = security_policy
      end

      private

      attr_reader :project, :security_policy

      def sync_project_approval_policy_rules_service
        Security::SecurityOrchestrationPolicies::SyncProjectApprovalPolicyRulesService.new(
          project: project, security_policy: security_policy
        )
      end
      strong_memoize_attr :sync_project_approval_policy_rules_service

      def link_policy
        return if policy_disabled_or_scope_inapplicable?

        security_policy.transaction do
          security_policy.link_project!(project)

          next unless security_policy.type_pipeline_execution_schedule_policy?

          recreate_pipeline_execution_schedule_project_schedules(project, security_policy)
        end

        return unless security_policy.type_approval_policy?

        sync_project_approval_policy_rules_service.create_rules

        track_branch_exceptions_bypass_settings
      end

      def unlink_policy
        security_policy.unlink_project!(project)

        sync_project_approval_policy_rules_service.delete_rules if security_policy.type_approval_policy?

        return unless security_policy.type_pipeline_execution_schedule_policy?

        security_policy
          .security_pipeline_execution_project_schedules
          .for_project(project)
          .delete_all
      end

      def scope_applicable?
        security_policy.scope_applicable?(project)
      end

      def policy_disabled_or_scope_inapplicable?
        !security_policy.enabled || !scope_applicable?
      end

      def recreate_pipeline_execution_schedule_project_schedules(project, security_policy)
        Security::SecurityOrchestrationPolicies::PipelineExecutionPolicies::CreateProjectSchedulesService
          .new(project: project, policy: security_policy)
          .execute
      end

      def track_branch_exceptions_bypass_settings
        return unless security_policy.bypass_settings.branches.any?

        track_internal_event('check_branch_exceptions_bypass_settings_for_approval_policy', project: project)
      end
    end
  end
end
