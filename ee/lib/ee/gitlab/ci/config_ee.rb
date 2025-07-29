# frozen_string_literal: true

module EE
  module Gitlab
    module Ci
      # This is named ConfigEE to avoid collisions with the
      # EE::Gitlab::Ci::Config namespace
      module ConfigEE
        extend ::Gitlab::Utils::Override

        override :rescue_errors
        def rescue_errors
          [
            *super,
            ::Gitlab::Ci::Config::Required::Processor::RequiredError
          ]
        end

        override :build_config
        def build_config(config, inputs)
          super
            .then { |config| process_required_includes(config) }
            .then { |config| enforce_pipeline_execution_policy_stages(config) }
            .then { |config| process_security_orchestration_policy_includes(config) }
        end

        def process_required_includes(config)
          return config unless required_pipelines_enabled?

          ::Gitlab::Ci::Config::Required::Processor.new(config).perform
        end

        def enforce_pipeline_execution_policy_stages(config)
          policy_context = pipeline_policy_context&.pipeline_execution_context
          return config if policy_context.nil?

          logger.instrument(:config_pipeline_execution_policy_stages_inject, once: true) do
            policy_context.enforce_stages!(config: config)
          end
        rescue ::Gitlab::Ci::Config::StagesMerger::InvalidStageConditionError => e
          raise ::Gitlab::Ci::Config::ConfigError, e.message
        end

        def process_security_orchestration_policy_includes(config)
          # We need to prevent SEP jobs from being injected into PEP pipelines
          # because they need to be added only into the main pipeline.
          return config if pipeline_policy_context&.creating_policy_pipeline?

          logger.instrument(:config_scan_execution_policy_processor, once: true) do
            ::Gitlab::Ci::Config::SecurityOrchestrationPolicies::Processor.new(config, context, source_ref_path,
              pipeline_policy_context).perform
          end
        end

        def required_pipelines_enabled?
          @project.present? && ::Feature.enabled?(:required_pipelines, @project) # rubocop:disable Gitlab/ModuleWithInstanceVariables -- temporary usage
        end
      end
    end
  end
end
