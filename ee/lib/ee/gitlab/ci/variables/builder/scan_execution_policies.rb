# frozen_string_literal: true

module EE
  module Gitlab
    module Ci
      module Variables
        module Builder
          class ScanExecutionPolicies
            include ::Gitlab::Utils::StrongMemoize

            attr_reader :project, :pipeline

            def initialize(pipeline)
              @pipeline = pipeline
              @project = pipeline.project
            end

            def variables(job_name)
              ::Gitlab::Ci::Variables::Collection.new.tap do |variables|
                next variables unless enforce_scan_execution_policies_variables?(job_name)

                variables_for_job(job_name).each do |key, value|
                  variables.append(key: key, value: value.to_s)
                end
              end
            end

            private

            def enforce_scan_execution_policies_variables?(job_name)
              return false if job_name.blank?

              project.licensed_feature_available?(:security_orchestration_policies)
            end

            def variables_for_job(job_name)
              active_scan_variables[job_name.to_sym] || []
            end

            def active_scan_variables
              ::Security::SecurityOrchestrationPolicies::ScanPipelineService
                .new(ci_context)
                .execute(active_scan_actions)[:variables]
            end
            strong_memoize_attr :active_scan_variables

            def active_scan_actions
              ::Gitlab::Security::Orchestration::ProjectPolicyConfigurations
                .new(project)
                .all
                .flat_map { |config| fetch_active_actions(config) }
                .compact
                .uniq
            end

            def ci_context
              ::Gitlab::Ci::Config::External::Context.new(project: project)
            end

            def fetch_active_actions(config)
              config.active_policies_scan_actions_for_project(pipeline.jobs_git_ref, project, pipeline.source)
            end
          end
        end
      end
    end
  end
end
