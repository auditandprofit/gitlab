# frozen_string_literal: true

module Security
  module PipelineExecutionSchedulePolicy
    POLICY_LIMIT = 1
    POLICY_TYPE_NAME = 'Pipeline execution schedule policy'

    def active_pipeline_execution_schedule_policies
      pipeline_execution_schedule_policy.select { |config| config[:enabled] }.first(POLICY_LIMIT)
    end

    def pipeline_execution_schedule_policy
      policy_by_type(:pipeline_execution_schedule_policy)
    end
  end
end
