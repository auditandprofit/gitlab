# frozen_string_literal: true

# This class encapsulates functionality related to Scan and Pipeline Execution Policies.
module Gitlab
  module Ci
    module Pipeline
      module ExecutionPolicies
        class PipelineContext
          include ::Gitlab::Utils::StrongMemoize

          def initialize(project:, command: nil)
            @project = project
            @command = command # TODO: decouple from this (https://gitlab.com/gitlab-org/gitlab/-/issues/503788)
          end

          delegate :policy_pipelines, :override_policy_stages, :build_policy_pipelines!,
            :creating_policy_pipeline?, :creating_project_pipeline?,
            :has_execution_policy_pipelines?, :has_overriding_execution_policy_pipelines?, :collect_declared_stages!,
            :inject_policy_stages?, :valid_stage?, :has_injected_stages?, :injected_policy_stages,
            :has_override_stages?, :policy_management_project_access_allowed?, :applying_config_override?,
            to: :pipeline_execution_context

          def pipeline_execution_context
            ::Gitlab::Ci::Pipeline::PipelineExecutionPolicies::PipelineContext
              .new(context: self, project: project, command: command)
          end
          strong_memoize_attr :pipeline_execution_context

          def scan_execution_context(ref)
            strong_memoize_with(:scan_execution_context, ref) do
              ::Gitlab::Ci::Pipeline::ScanExecutionPolicies::PipelineContext.new(
                project: project,
                ref: ref,
                current_user: command&.current_user,
                source: command&.source)
            end
          end

          def skip_ci_allowed?(ref:)
            pipeline_execution_context.skip_ci_allowed? && scan_execution_context(ref).skip_ci_allowed?
          end

          private

          attr_reader :project, :command
        end
      end
    end
  end
end
