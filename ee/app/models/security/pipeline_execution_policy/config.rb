# frozen_string_literal: true

# This class is the object representation of a single entry in the policy.yml
module Security
  module PipelineExecutionPolicy
    class Config
      include Gitlab::Utils::StrongMemoize
      include ::Security::PolicyCiSkippable

      DEFAULT_SUFFIX_STRATEGY = 'on_conflict'
      SUFFIX_STRATEGIES = { on_conflict: 'on_conflict', never: 'never' }.freeze
      DEFAULT_SKIP_CI_STRATEGY = { allowed: false }.freeze
      POLICY_JOB_SUFFIX = ':policy'

      attr_reader :content, :config_strategy, :suffix_strategy, :policy_project_id, :policy_index, :name,
        :skip_ci_strategy, :variables_override_strategy, :policy_config

      delegate :experiment_enabled?, to: :policy_config

      def initialize(policy:, policy_config:, policy_index:)
        @content = policy.fetch(:content).to_yaml
        @policy_config = policy_config
        @policy_project_id = policy_config.security_policy_management_project_id
        @policy_index = policy_index
        @config_strategy = policy.fetch(:pipeline_config_strategy).to_sym
        @suffix_strategy = policy[:suffix] || DEFAULT_SUFFIX_STRATEGY
        @name = policy.fetch(:name)
        @skip_ci_strategy = policy[:skip_ci].presence || DEFAULT_SKIP_CI_STRATEGY
        @variables_override_strategy = policy[:variables_override]
      end

      def strategy_override_project_ci?
        config_strategy == :override_project_ci
      end

      # New inject CI strategy that allows custom policy stages to be injected into the project CI config.
      # It is going to replace `inject_ci` strategy.
      def strategy_inject_policy?
        config_strategy == :inject_policy
      end

      def suffix
        return if suffix_strategy == SUFFIX_STRATEGIES[:never]

        [POLICY_JOB_SUFFIX, policy_project_id, policy_index].join("-")
      end
      strong_memoize_attr :suffix

      def suffix_on_conflict?
        suffix_strategy == SUFFIX_STRATEGIES[:on_conflict]
      end

      def skip_ci_allowed?(user_id)
        skip_ci_allowed_for_strategy?(skip_ci_strategy, user_id)
      end
    end
  end
end
