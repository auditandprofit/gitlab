# frozen_string_literal: true

# EE:Self Managed
module Admin
  module GitlabDuo
    class ConfigurationController < Admin::ApplicationController
      before_action :ensure_feature_available!

      respond_to :html

      feature_category :ai_abstraction_layer
      urgency :low

      def index; end

      private

      def ensure_feature_available!
        return if !Gitlab::Saas.feature_available?(:gitlab_com_subscriptions) &&
          GitlabSubscriptions::Duo.active_self_managed_duo_core_pro_or_enterprise? &&
          License.current&.paid?

        redirect_to admin_gitlab_duo_path
      end
    end
  end
end
