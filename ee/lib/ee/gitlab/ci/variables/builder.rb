# frozen_string_literal: true

module EE
  module Gitlab
    module Ci
      module Variables
        module Builder
          extend ::Gitlab::Utils::Override

          override :initialize
          def initialize(pipeline)
            super

            @scan_execution_policies_variables_builder =
              ::Gitlab::Ci::Variables::Builder::ScanExecutionPolicies.new(pipeline)
          end

          override :scoped_variables_for_pipeline_seed
          def scoped_variables_for_pipeline_seed(job_attr, environment:, kubernetes_namespace:, user:, trigger:)
            variables = super.tap do |variables|
              variables.concat(scan_execution_policies_variables_builder.variables(job_attr[:name]))
            end

            ::Security::PipelineExecutionPolicy::VariablesOverride
              .new(project: project, job_options: job_attr[:options])
              .apply_highest_precedence(variables, job_attr[:yaml_variables])
          end

          # When adding new variables, consider either adding or commenting out them in the following methods:
          # - unprotected_scoped_variables
          # - scoped_variables_for_pipeline_seed
          override :scoped_variables
          def scoped_variables(job, environment:, dependencies:)
            variables = super.tap do |variables|
              variables.concat(scan_execution_policies_variables_builder.variables(job.name))
            end

            ::Security::PipelineExecutionPolicy::VariablesOverride
              .new(project: project, job_options: job.options)
              .apply_highest_precedence(variables, job.yaml_variables)
          end

          private

          attr_reader :scan_execution_policies_variables_builder

          override :user_defined_variables
          def user_defined_variables(
            options:, environment:, job_variables: nil, expose_group_variables: protected_ref?,
            expose_project_variables: protected_ref?)
            ::Security::PipelineExecutionPolicy::VariablesOverride.new(project: project, job_options: options)
                                                                  .apply_variables_override(super)
          end
        end
      end
    end
  end
end
