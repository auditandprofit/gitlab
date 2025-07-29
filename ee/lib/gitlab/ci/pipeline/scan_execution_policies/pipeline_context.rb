# frozen_string_literal: true

# This class encapsulates functionality related to Scan Execution Policies and is used during pipeline creation.
module Gitlab
  module Ci
    module Pipeline
      module ScanExecutionPolicies
        class PipelineContext
          include ::Gitlab::Utils::StrongMemoize

          def initialize(project:, ref:, current_user:, source:)
            @project = project
            @ref = ref
            @current_user = current_user
            @source = source
            @injected_job_names = []
          end

          def has_scan_execution_policies?
            apply_scan_execution_policies? && policies.present?
          end

          def active_scan_execution_actions
            policies.flat_map { |policy| limited_actions(policy.actions) }.compact.uniq
          end
          strong_memoize_attr :active_scan_execution_actions

          def skip_ci_allowed?
            return true unless has_scan_execution_policies?

            policies.all? { |policy| policy.skip_ci_allowed?(current_user&.id) }
          end

          def collect_injected_job_names(job_names)
            @injected_job_names.concat(job_names.map(&:to_s))
          end

          def job_injected?(job)
            @injected_job_names.include?(job.name)
          end

          private

          attr_reader :project, :ref, :current_user, :source

          def limited_actions(actions)
            action_limit = Gitlab::CurrentSettings.scan_execution_policies_action_limit

            return actions if action_limit == 0

            actions.first(action_limit)
          end

          def apply_scan_execution_policies?
            return false unless project&.feature_available?(:security_orchestration_policies)
            return false unless Enums::Ci::Pipeline.ci_sources.key?(source&.to_sym)

            project.security_policies.type_scan_execution_policy.exists?
          end

          def policies
            return [] if valid_security_orchestration_policy_configurations.blank?

            policies = valid_security_orchestration_policy_configurations
              .flat_map do |configuration|
              configuration.active_pipeline_policies_for_project(ref, project, source)
            end.compact

            policies.map do |policy|
              ::Security::ScanExecutionPolicy::Config.new(policy: policy)
            end
          end
          strong_memoize_attr :policies

          def valid_security_orchestration_policy_configurations
            @valid_security_orchestration_policy_configurations ||=
              ::Gitlab::Security::Orchestration::ProjectPolicyConfigurations.new(project).all
          end
        end
      end
    end
  end
end
