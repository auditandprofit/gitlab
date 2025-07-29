# frozen_string_literal: true

module Groups
  module Settings
    class ServiceAccountsController < Groups::ApplicationController
      include ::GitlabSubscriptions::SubscriptionHelper

      feature_category :user_management

      before_action :ensure_root_group!
      before_action :authorize_admin_service_accounts!

      before_action do
        push_frontend_feature_flag(:edit_service_account_email, group)
      end

      private

      def authorize_admin_service_accounts!
        render_404 unless can?(current_user, :create_service_account, group) &&
          can?(current_user, :delete_service_account, group)
      end

      def ensure_root_group!
        render_404 unless group.root?
      end
    end
  end
end
