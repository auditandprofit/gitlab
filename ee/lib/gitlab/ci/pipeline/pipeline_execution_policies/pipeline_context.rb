# frozen_string_literal: true

# This class encapsulates functionality related to Pipeline Execution Policies and is used during pipeline creation.
module Gitlab
  module Ci
    module Pipeline
      module PipelineExecutionPolicies
        OverrideStagesConflictError = Class.new(StandardError)

        class PipelineContext
          include ::Gitlab::Utils::StrongMemoize

          HISTOGRAMS = {
            single_pipeline: :gitlab_security_policies_pipeline_execution_policy_dry_run_pipeline,
            all_pipelines: :gitlab_security_policies_pipeline_execution_policy_build_policy_pipelines
          }.freeze

          attr_reader :policy_pipelines, :override_policy_stages, :injected_policy_stages

          def initialize(context:, project:, command: nil)
            @context = context
            @project = project
            @command = command # TODO: decouple from this (https://gitlab.com/gitlab-org/gitlab/-/issues/503788)
            @policy_pipelines = []
            @override_policy_stages = []
            @injected_policy_stages = []
          end

          def build_policy_pipelines!(partition_id)
            return if creating_policy_pipeline?
            return if policies.empty?

            measure(HISTOGRAMS.fetch(:all_pipelines), labels: { policy_count: policies.size }) do
              policies.each do |policy|
                response = create_pipeline(policy, partition_id)
                pipeline = response.payload

                if response.success?
                  @policy_pipelines << ::Security::PipelineExecutionPolicy::Pipeline.new(
                    pipeline: pipeline, policy_config: policy)
                elsif pipeline.filtered_as_empty?
                # no-op: we ignore empty pipelines
                elsif block_given?
                  yield response.message
                end
              end
            end
          end

          def policy_management_project_access_allowed?
            creating_policy_pipeline? || scheduled_execution_policy_pipeline?
          end

          def creating_policy_pipeline?
            current_policy.present?
          end

          def creating_project_pipeline?
            !creating_policy_pipeline?
          end

          def has_execution_policy_pipelines?
            policy_pipelines.present?
          end

          def scheduled_execution_policy_pipeline?
            return false if Feature.disabled?(:scheduled_pipeline_execution_policies, project)

            command&.source == ::Security::PipelineExecutionPolicies::RunScheduleWorker::PIPELINE_SOURCE
          end

          def skip_ci_allowed?
            return true unless has_execution_policy_pipelines?

            policy_pipelines.all? { |policy_pipeline| policy_pipeline.skip_ci_allowed?(command.current_user&.id) }
          end

          def has_overriding_execution_policy_pipelines?
            policies.any?(&:strategy_override_project_ci?)
          end

          def applying_config_override?
            has_overriding_execution_policy_pipelines? && creating_project_pipeline?
          end

          def collect_declared_stages!(new_stages)
            return unless creating_policy_pipeline?

            if current_policy.strategy_override_project_ci?
              collect_declared_override_stages!(new_stages)
            elsif current_policy.strategy_inject_policy?
              @injected_policy_stages << new_stages
            end
          end

          def has_override_stages?
            # Stages collected from all `override_project_ci` policies that are applied on the main pipeline.
            override_policy_stages.present?
          end

          def has_injected_stages?
            # The stages are applied on the main pipeline based on all policy pipelines.
            injected_policy_stages.present?
          end

          # We inject policy stages only when;
          # - creating_policy_pipeline?: This is a temporary pipeline creation mode.
          #   We need to inject these stages for the validation because the policy may use them.
          # - has_execution_policy_pipelines?: This is the actual pipeline creation mode.
          #   It means that the result pipeline will have PEPs.
          #   We need to inject these stages because some of the policies may use them.
          # - this is a scheduled PEP pipeline
          def inject_policy_stages?
            creating_policy_pipeline? || has_execution_policy_pipelines? || scheduled_execution_policy_pipeline?
          end

          def valid_stage?(stage)
            return true if creating_policy_pipeline? || scheduled_execution_policy_pipeline?

            ::Gitlab::Ci::Config::Stages::RESERVED.exclude?(stage)
          end

          def enforce_stages!(config:)
            return config unless inject_policy_stages?

            config = ::Gitlab::Ci::Config::Stages.new(config).inject_reserved_stages!
            return config if creating_policy_pipeline?

            config[:stages] = override_policy_stages if has_override_stages?

            if has_injected_stages?
              config[:stages] = ::Gitlab::Ci::Config::StagesMerger.inject(config[:stages], injected_policy_stages)
            end

            config
          rescue ::Gitlab::Ci::Config::StagesMerger::InvalidStageConditionError => e
            raise e, 'Pipeline execution policy error: Cyclic dependencies detected when enforcing policies. ' \
              'Ensure stages across the project and policies are aligned.'
          end

          def job_options
            return {} unless creating_policy_pipeline?

            {
              execution_policy_job: true,
              execution_policy_name: current_policy.name,
              execution_policy_variables_override: current_policy.variables_override_strategy
            }
          end

          private

          attr_reader :project, :command, :current_policy

          def policies
            return [] if command&.source.blank?
            return [] if Enums::Ci::Pipeline.dangling_sources.key?(command.source&.to_sym)

            ::Gitlab::Security::Orchestration::ProjectPipelineExecutionPolicies.new(project).configs
          end
          strong_memoize_attr :policies

          def create_pipeline(policy, partition_id)
            measure(HISTOGRAMS.fetch(:single_pipeline)) do
              with_policy_context(policy) do
                ::Ci::CreatePipelineService
                  .new(project, command.current_user,
                    ref: command.ref,
                    before: command.before_sha,
                    after: command.after_sha,
                    source_sha: command.source_sha,
                    checkout_sha: command.checkout_sha,
                    target_sha: command.target_sha,
                    partition_id: partition_id,
                    variables_attributes: command.variables_attributes,
                    chat_data: command.chat_data)
                  .execute(command.source,
                    content: policy.content,
                    pipeline_policy_context: @context, # propagates parent context inside the policy pipeline creation
                    merge_request: command.merge_request, # This is for supporting merge request pipelines,
                    schedule: command.schedule,
                    ignore_skip_ci: true # We can exit early from `Chain::Skip` by setting this parameter
                    # Additional parameters will be added in https://gitlab.com/gitlab-org/gitlab/-/issues/462004
                  )
              end
            end
          end

          # We are setting `@current_policy` to the policy we're currently building the pipeline for.
          # By passing this context into the policy pipeline creation, we can evaluate policy-specific logic from within
          # `CreatePipelineService` by delegating to this object.
          # For example, it allows us to collect declared stages if @current_policy is `override_project_ci`.
          def with_policy_context(policy)
            @current_policy = policy
            yield.tap do
              @current_policy = nil
            end
          end

          def collect_declared_override_stages!(new_stages)
            error = OverrideStagesConflictError.new(
              "Policy `#{current_policy.name}` could not be applied. " \
                "Its stages are incompatible with stages of another `override_project_ci` policy: " \
                "#{override_policy_stages.join(', ')}.")

            if new_stages.size > override_policy_stages.size
              raise error unless stages_compatible?(override_policy_stages, new_stages)

              @override_policy_stages = new_stages
            else
              raise error unless stages_compatible?(new_stages, override_policy_stages)
            end
          end

          # `stages` are considered compatible if they are an ordered subset of `target_stages`.
          # `target_stages` is larger or equally large set of stages.
          # Elements of `stages` must appear in the same order as in `target_stages`.
          # Valid example:
          #   `stages`: [build, deploy]
          #   `target_stages`: [build, test, deploy]
          # Invalid example:
          #   `stages`: [deploy, build]
          #   `target_stages`: [build, test, deploy]
          def stages_compatible?(stages, target_stages)
            stages == target_stages & stages
          end

          delegate :measure, to: ::Security::SecurityOrchestrationPolicies::ObserveHistogramsService
        end
      end
    end
  end
end
