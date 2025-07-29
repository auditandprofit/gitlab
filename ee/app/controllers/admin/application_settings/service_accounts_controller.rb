# frozen_string_literal: true

module Admin
  module ApplicationSettings
    class ServiceAccountsController < Admin::ApplicationController
      include ::GitlabSubscriptions::SubscriptionHelper

      feature_category :user_management

      before_action :authorize_admin_service_accounts!

      before_action do
        push_frontend_feature_flag(:edit_service_account_email, current_user)
      end

      private

      def authorize_admin_service_accounts!
        render_404 if gitlab_com_subscription? || !can?(current_user, :admin_service_accounts)
      end
    end
  end
end
