# frozen_string_literal: true

# rubocop:disable Gitlab/ModuleWithInstanceVariables
module EE
  module Admin
    module DashboardController
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      override :index
      def index
        super

        @license = License.current
      end

      private

      override :user_is_admin?
      def user_is_admin?
        current_user.can_access_admin_area?
      end
    end
  end
end
