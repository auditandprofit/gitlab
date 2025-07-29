# frozen_string_literal: true

module Security
  module CiComponentPublishingPolicy
    POLICY_LIMIT = 5
    POLICY_TYPE_NAME = 'CI component publishing policy'

    def active_ci_component_publishing_policies
      ci_component_publishing_policy.select { |config| config[:enabled] }.first(POLICY_LIMIT)
    end

    def ci_component_publishing_policy
      policy_by_type(:ci_component_publishing_policy)
    end
  end
end
