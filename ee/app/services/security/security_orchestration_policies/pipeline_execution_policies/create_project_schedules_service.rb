# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    module PipelineExecutionPolicies
      class CreateProjectSchedulesService
        include Gitlab::Loggable

        EVENT_KEY = 'scheduled_pipeline_execution_policy_schedule_persistence_failure'

        def initialize(project:, policy:)
          @project = project
          @policy = policy
        end

        def execute
          schedules = policy.content.fetch("schedules")

          policy.transaction do
            policy
              .security_pipeline_execution_project_schedules
              .for_project(project)
              .delete_all

            policy.security_pipeline_execution_project_schedules.create!(attributes(schedules)) if feature_enabled?
          end

          ServiceResponse.success
        rescue StandardError => e
          log_project_schedules_creation_error(e, policy)

          raise e
        end

        private

        attr_reader :project, :policy

        def attributes(schedules)
          intervals(schedules).map do |interval|
            {
              project_id: project.id,
              cron: interval.cron,
              cron_timezone: interval.time_zone,
              time_window_seconds: interval.time_window,
              snoozed_until: interval.snoozed_until
            }
          end
        end

        def intervals(schedules)
          Gitlab::Security::Orchestration::PipelineExecutionPolicies::Intervals.from_schedules(schedules)
        end

        def log_project_schedules_creation_error(error, policy)
          Gitlab::AppJsonLogger.error(
            build_structured_payload(
              event: EVENT_KEY,
              exception_class: error.class.name,
              exception_message: error.message,
              project_id: project.id,
              policy_id: policy.id))
        end

        def feature_enabled?
          return false if Feature.disabled?(:scheduled_pipeline_execution_policies, project)

          policy.security_orchestration_policy_configuration.experiment_enabled?(:pipeline_execution_schedule_policy)
        end
      end
    end
  end
end
