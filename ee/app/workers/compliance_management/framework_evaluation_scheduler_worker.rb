# frozen_string_literal: true

module ComplianceManagement
  class FrameworkEvaluationSchedulerWorker
    include ApplicationWorker
    include CronjobQueue # rubocop:disable Scalability/CronWorkerContext -- does not require context

    version 1
    urgency :throttled
    data_consistency :sticky
    feature_category :compliance_management
    sidekiq_options retry: false
    idempotent!

    FRAMEWORK_BATCH_SIZE = 100
    PROJECT_BATCH_SIZE = 100

    def perform
      return unless Feature.enabled?(:evaluate_compliance_controls, :instance)

      active_control_frameworks.each_batch(of: FRAMEWORK_BATCH_SIZE) do |batch|
        batch.each do |framework|
          enqueue_framework_evaluation(framework)
        end
      end
    end

    private

    def active_control_frameworks
      ComplianceManagement::Framework.with_active_controls
    end

    def enqueue_framework_evaluation(framework)
      framework.projects.each_batch(of: PROJECT_BATCH_SIZE) do |projects_batch|
        ProjectComplianceEvaluatorWorker.perform_async(
          framework.id,
          projects_batch.pluck_primary_key
        )
      end
    end
  end
end
