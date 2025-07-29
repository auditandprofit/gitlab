# frozen_string_literal: true

module EE
  module Gitlab
    module Ci
      module Pipeline
        module Chain
          module Command
            extend ::Gitlab::Utils::Override

            override :dry_run?
            def dry_run?
              super || !!pipeline_policy_context&.creating_policy_pipeline?
            end

            override :pipeline_policy_context
            def pipeline_policy_context
              self[:pipeline_policy_context] ||= ::Gitlab::Ci::Pipeline::ExecutionPolicies::PipelineContext.new(
                project: project,
                command: self
              )
            end

            def increment_duplicate_job_name_errors_counter(suffix_strategy)
              metrics.duplicate_job_name_errors_counter.increment(suffix_strategy: suffix_strategy)
            end
          end
        end
      end
    end
  end
end
