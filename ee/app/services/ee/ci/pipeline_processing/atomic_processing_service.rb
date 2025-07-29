# frozen_string_literal: true

module EE
  module Ci
    module PipelineProcessing
      module AtomicProcessingService
        extend ::Gitlab::Utils::Override
        include ::Gitlab::Utils::StrongMemoize

        private

        override :status_of_previous_jobs_dag
        def status_of_previous_jobs_dag(job)
          status = super

          calculate_status_based_on_reserved_pre_stage(status, job)
        end

        # Returns a running status for previous jobs as long as the reserved pre stage is not completed.
        # This is to ensure jobs can not circumvent enforces security checks.
        def calculate_status_based_on_reserved_pre_stage(status, job)
          return status if !reserved_pre_stage || job.ci_stage.reserved_pre?

          reserved_pre_stage_completed? ? status : 'running'
        end

        def reserved_pre_stage_completed?
          ::Ci::HasStatus::COMPLETED_STATUSES.include?(collection.status_of_stage(reserved_pre_stage.position))
        end
        strong_memoize_attr :reserved_pre_stage_completed?

        def reserved_pre_stage
          pipeline.stages.find(&:reserved_pre?)
        end
        strong_memoize_attr :reserved_pre_stage
      end
    end
  end
end
