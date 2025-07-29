# frozen_string_literal: true

module Security
  module ScanExecutionPolicies
    class CreatePipelineWorker # rubocop:disable Scalability/IdempotentWorker -- The worker should not run multiple times to avoid creating multiple pipelines
      include ApplicationWorker
      include Gitlab::InternalEventsTracking

      feature_category :security_policy_management
      deduplicate :until_executing
      urgency :throttled
      data_consistency :delayed
      worker_resource_boundary :cpu

      concurrency_limit -> { 1000 }

      def perform(project_id, current_user_id, schedule_id, branch)
        project = Project.find_by_id(project_id)
        return unless project

        current_user = User.find_by_id(current_user_id)
        return unless current_user

        schedule = Security::OrchestrationPolicyRuleSchedule.find_by_id(schedule_id)
        return unless schedule

        actions = actions_for(schedule)

        service_result = ::Security::SecurityOrchestrationPolicies::CreatePipelineService
          .new(project: project, current_user: current_user, params: { actions: actions, branch: branch })
          .execute

        track_creation_event(project, schedule, actions.size, service_result[:status])

        return unless service_result[:status] == :error

        log_error(current_user, schedule, service_result[:message])
      end

      private

      def actions_for(schedule)
        policy = schedule.policy

        return [] if policy.blank?

        actions = policy[:actions]
        action_limit = Gitlab::CurrentSettings.scan_execution_policies_action_limit

        return actions if action_limit == 0

        actions.first(action_limit)
      end

      def track_creation_event(project, schedule, scans_count, result)
        track_internal_event(
          'enforce_scheduled_scan_execution_policy_in_project',
          project: project,
          additional_properties: {
            value: scans_count, # Number of enforced scans,
            label: result.to_s, # Was the creation of the pipeline successful,
            property: schedule.policy_source,
            time_window: schedule.time_window.present? ? 1 : 0 # time_window was used to distribute scans or not
          }
        )
      end

      def log_error(current_user, schedule, message)
        ::Gitlab::AppJsonLogger.warn(
          build_structured_payload(
            security_orchestration_policy_configuration_id: schedule&.security_orchestration_policy_configuration&.id,
            user_id: current_user.id,
            message: message
          )
        )
      end
    end
  end
end
