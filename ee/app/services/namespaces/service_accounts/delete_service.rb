# frozen_string_literal: true

module Namespaces
  module ServiceAccounts
    class DeleteService < BaseService
      attr_accessor :current_user, :user

      def initialize(current_user, user)
        @current_user = current_user
        @user = user
      end

      def execute(options = {})
        return error(error_messages[:no_permission], :forbidden) unless can_delete_service_account?

        delete_user(options)

        return error(user.errors.full_messages.to_sentence, :bad_request) if user.errors.present?

        success
      end

      private

      def can_delete_service_account?
        can?(current_user, :delete_service_account, user.provisioned_by_group)
      end

      def delete_user(options)
        # Since we do authorization checks in this class
        # for delete_service_account, the Users::DestroyService can
        # skip checks for delete_user
        options[:skip_authorization] = true
        user.delete_async(deleted_by: current_user, params: options)
      end

      def error_messages
        {
          no_permission: s_('ServiceAccount|User does not have permission to delete a service account.')
        }
      end

      def error(message, reason)
        ServiceResponse.error(message: message, reason: reason)
      end

      def success
        ServiceResponse.success(message: "User successfully deleted")
      end
    end
  end
end
