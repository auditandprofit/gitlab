# frozen_string_literal: true

# Activating self-managed instances
# Part of Cloud Licensing https://gitlab.com/groups/gitlab-org/-/epics/1735
module GitlabSubscriptions
  class UpdateLicenseDependenciesService
    include Gitlab::Utils::StrongMemoize

    def initialize(future_subscriptions:, license:, new_subscription:)
      @future_subscriptions = future_subscriptions
      @license = license
      @new_subscription = new_subscription
    end

    def execute
      save_future_subscriptions
      update_add_on_purchases
      auto_enable_duo_core_features

      { future_subscriptions: application_settings.future_subscriptions }
    end

    private

    attr_reader :future_subscriptions, :license, :new_subscription

    def save_future_subscriptions
      future_subscriptions_value = future_subscriptions.presence || []

      application_settings.update!(future_subscriptions: future_subscriptions_value)
    rescue ActiveRecord::ActiveRecordError => err
      Gitlab::ErrorTracking.track_and_raise_for_dev_exception(err)
    end

    def application_settings
      Gitlab::CurrentSettings.current_application_settings
    end
    strong_memoize_attr :application_settings

    def update_add_on_purchases
      ::GitlabSubscriptions::AddOnPurchases::SelfManaged::ProvisionServices::Duo.new.execute
    end

    def auto_enable_duo_core_features
      return unless auto_enable_duo_core_features?

      ai_setting.update!(duo_core_features_enabled: true)
    rescue ActiveRecord::ActiveRecordError => err
      Gitlab::ErrorTracking.track_and_raise_for_dev_exception(err)
    end

    def auto_enable_duo_core_features?
      return false unless new_subscription.present?
      return false unless license&.started?
      return false unless no_user_action_on_duo_core_setting?
      return false unless active_duo_core_add_on?

      true
    end

    def no_user_action_on_duo_core_setting?
      ai_setting.duo_core_features_enabled.nil?
    end

    def ai_setting
      Ai::Setting.instance
    end
    strong_memoize_attr :ai_setting

    def active_duo_core_add_on?
      GitlabSubscriptions::AddOnPurchase.for_self_managed.for_duo_core.active.exists?
    end
  end
end
