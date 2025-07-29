# frozen_string_literal: true

module EE
  module Gitlab
    module Ci
      module Pipeline
        module Chain
          module SetBuildSources
            extend ::Gitlab::Utils::Override

            override :pipeline_execution_policy_build?
            def pipeline_execution_policy_build?(build)
              build.options&.dig(:execution_policy_job)
            end

            override :scan_execution_policy_build?
            def scan_execution_policy_build?(build)
              command.pipeline_policy_context.scan_execution_context(pipeline.source_ref_path)
                .job_injected?(build)
            end
          end
        end
      end
    end
  end
end
