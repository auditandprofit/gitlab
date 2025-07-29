# frozen_string_literal: true

# This class is the object representation of a pipeline created by a policy
module Security
  module PipelineExecutionPolicy
    class Pipeline
      def initialize(pipeline:, policy_config:)
        @pipeline = pipeline
        @policy_config = policy_config
      end

      attr_reader :pipeline, :policy_config

      delegate :suffix_strategy, :suffix, :suffix_on_conflict?, :config_strategy, :variables_override_strategy,
        :strategy_override_project_ci?, :strategy_inject_policy?, :skip_ci_allowed?, to: :policy_config
    end
  end
end
