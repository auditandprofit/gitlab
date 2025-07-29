# frozen_string_literal: true

module EE
  module Gitlab
    module GonHelper
      extend ::Gitlab::Utils::Override

      override :add_gon_variables
      def add_gon_variables
        super

        gon.roadmap_epics_limit = 1000

        if current_user && defined?(Llm)
          ai_chat = {
            total_model_token: ::Llm::ExplainCodeService::TOTAL_MODEL_TOKEN_LIMIT,
            max_response_token: ::Llm::ExplainCodeService::MAX_RESPONSE_TOKENS,
            input_content_limit: ::Llm::ExplainCodeService::INPUT_CONTENT_LIMIT
          }

          push_to_gon_attributes('ai', 'chat', ai_chat)
        end

        push_frontend_feature_flags

        return unless ::Gitlab.com?

        gon.subscriptions_url                = ::Gitlab::Routing.url_helpers.subscription_portal_url
        gon.subscriptions_legacy_sign_in_url = ::Gitlab::Routing.url_helpers.subscription_portal_legacy_sign_in_url
        gon.billing_accounts_url             = ::Gitlab::Routing.url_helpers.subscription_portal_billing_accounts_url
        gon.payment_form_url                 = ::Gitlab::Routing.url_helpers.subscription_portal_payment_form_url
        gon.payment_validation_form_id       = ::Gitlab::SubscriptionPortal::PAYMENT_VALIDATION_FORM_ID
      end

      def push_frontend_feature_flags
        push_frontend_feature_flag(:duo_chat_dynamic_dimension, current_user)
        push_frontend_feature_flag(:advanced_context_resolver, current_user)
        push_frontend_feature_flag(:vulnerability_report_type_scanner_filter, current_user)
      end

      # Exposes if a licensed feature is available.
      #
      # name - The name of the licensed feature
      # obj  - the object to check the licensed feature on (project, namespace)
      def push_licensed_feature(name, obj = nil)
        enabled = if obj
                    obj.feature_available?(name)
                  else
                    ::License.feature_available?(name)
                  end

        push_to_gon_attributes(:licensed_features, name, enabled)
      end

      # Exposes if a SaaS feature is available.
      #
      # name - The name of the SaaS feature
      def push_saas_feature(name)
        push_to_gon_attributes(:saas_features, name, ::Gitlab::Saas.feature_available?(name))
      end
    end
  end
end
