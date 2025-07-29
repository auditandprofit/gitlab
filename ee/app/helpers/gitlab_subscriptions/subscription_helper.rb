# frozen_string_literal: true

module GitlabSubscriptions
  module SubscriptionHelper
    def self.gitlab_com_subscription?
      # There is a plan to enable self-hosted features on Staging Ref:
      #
      # https://gitlab.com/gitlab-org/gitlab/-/issues/497784
      #
      # The problem is that it's a .com environment. Let's introduce a feature flag for now
      # to allow AI features on .com.
      return false if ::Feature.enabled?(:allow_self_hosted_features_for_com) # rubocop:disable Gitlab/FeatureFlagWithoutActor -- The feature flag is global

      ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
    end

    def gitlab_com_subscription?
      GitlabSubscriptions::SubscriptionHelper.gitlab_com_subscription?
    end
  end
end
