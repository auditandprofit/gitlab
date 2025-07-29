# frozen_string_literal: true

module Nav
  module GitlabDuoSettingsPage
    include ::GitlabSubscriptions::SubscriptionHelper
    include ::GitlabSubscriptions::CodeSuggestionsHelper

    def show_gitlab_duo_settings_menu_item?(group)
      group.usage_quotas_enabled? &&
        show_gitlab_duo_settings_app?(group)
    end

    def show_gitlab_duo_settings_app?(group)
      # Guard this feature for EE users only https://docs.gitlab.com/ee/development/ee_features.html#guard-your-ee-feature
      # This is to prevent it showing up in CE and free EE
      License.feature_available?(:code_suggestions) &&
        gitlab_com_subscription? &&
        (
          !group.has_free_or_no_subscription? ||
          # group has Duo Pro add-on trial on a Free tier
          GitlabSubscriptions::Trials::DuoPro.show_duo_usage_settings?(group)
        )
    end
  end
end
