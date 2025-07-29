# frozen_string_literal: true

module Namespaces
  module ServiceAccounts
    class UpdateService < ::Users::ServiceAccounts::UpdateService
      extend ::Gitlab::Utils::Override

      attr_reader :group_id

      def initialize(current_user, user, params = {})
        super
        @group_id = params[:group_id]
      end

      override :execute
      def execute
        return error(error_messages[:group_not_found], :not_found) unless group.present?
        return error(error_messages[:invalid_group_id], :bad_request) unless group.id == user.provisioned_by_group&.id

        super
      end

      private

      override :can_update_service_account?
      def can_update_service_account?
        Ability.allowed?(current_user, :admin_service_accounts, user.provisioned_by_group)
      end

      def group
        @_group ||= ::Group.find_by_id(@group_id)
      end

      override :skip_confirmation?
      def skip_confirmation?
        super || group.owner_of_email?(params[:email])
      end

      override :error_messages
      def error_messages
        super.merge(
          no_permission:
            s_('ServiceAccount|You are not authorized to update service accounts in this namespace.'),
          invalid_group_id: s_('ServiceAccount|Group ID provided does not match the service account\'s group ID.'),
          group_not_found: s_('ServiceAccount|Group with the provided ID not found.')
        )
      end
    end
  end
end
