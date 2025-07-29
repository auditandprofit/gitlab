# frozen_string_literal: true

module Admin
  class AiConfigurationPresenter
    include Gitlab::Utils::StrongMemoize

    delegate :disabled_direct_code_suggestions?,
      :duo_availability,
      :duo_chat_expiration_column,
      :duo_chat_expiration_days,
      :enabled_expanded_logging,
      :gitlab_dedicated_instance?,
      :instance_level_ai_beta_features_enabled,
      :model_prompt_cache_enabled?,
      to: :application_settings

    delegate :ai_gateway_url,
      :duo_core_features_enabled?,
      to: :ai_settings

    def settings
      {
        ai_gateway_url: ai_gateway_url,
        are_experiment_settings_allowed: active_duo_add_ons_exist?,
        are_prompt_cache_settings_allowed: true,
        beta_self_hosted_models_enabled: beta_self_hosted_models_enabled,
        can_manage_self_hosted_models: can_manage_self_hosted_models?,
        disabled_direct_connection_method: disabled_direct_code_suggestions?,
        duo_availability: duo_availability,
        duo_chat_expiration_column: duo_chat_expiration_column,
        duo_chat_expiration_days: duo_chat_expiration_days,
        duo_core_features_enabled: duo_core_features_enabled?,
        duo_pro_visible: active_duo_add_ons_exist?,
        enabled_expanded_logging: enabled_expanded_logging,
        experiment_features_enabled: instance_level_ai_beta_features_enabled,
        on_general_settings_page: false,
        prompt_cache_enabled: model_prompt_cache_enabled?,
        redirect_path: url_helpers.admin_gitlab_duo_path,
        toggle_beta_models_path: url_helpers.admin_ai_duo_self_hosted_toggle_beta_models_path
      }.transform_values(&:to_s)
    end

    private

    def active_duo_add_ons_exist?
      ::GitlabSubscriptions::AddOnPurchase.active_duo_add_ons_exist?(:instance)
    end

    def beta_self_hosted_models_enabled
      ::Ai::TestingTermsAcceptance.has_accepted?
    end

    def can_manage_self_hosted_models?
      return false if ::Gitlab::CurrentSettings.gitlab_dedicated_instance?

      has_required_license = ::License.feature_available?(:self_hosted_models)
      has_duo_enterprise = ::GitlabSubscriptions::DuoEnterprise.active_add_on_purchase_for_self_managed?

      has_required_license && has_duo_enterprise
    end

    def url_helpers
      Gitlab::Routing.url_helpers
    end

    def application_settings
      Gitlab::CurrentSettings.expire_current_application_settings
      Gitlab::CurrentSettings.current_application_settings
    end
    strong_memoize_attr :application_settings

    def ai_settings
      ::Ai::Setting.instance
    end
    strong_memoize_attr :ai_settings
  end
end
