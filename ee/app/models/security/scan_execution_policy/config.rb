# frozen_string_literal: true

# This class is the object representation of a single entry in the policy.yml
module Security
  module ScanExecutionPolicy
    class Config
      include ::Security::PolicyCiSkippable

      DEFAULT_SKIP_CI_STRATEGY = { allowed: true }.freeze

      attr_reader :actions, :skip_ci_strategy

      def initialize(policy:)
        @actions = policy.fetch(:actions)
        @skip_ci_strategy = policy[:skip_ci].presence || DEFAULT_SKIP_CI_STRATEGY
      end

      def skip_ci_allowed?(user_id)
        skip_ci_allowed_for_strategy?(skip_ci_strategy, user_id)
      end
    end
  end
end
