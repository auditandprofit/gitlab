# frozen_string_literal: true

module Admin
  module TargetedMessagesHelper
    def targeted_message_id_for(group)
      return unless Feature.enabled?(:targeted_messages_admin_ui, :instance) &&
        ::Gitlab::Saas.feature_available?(:targeted_messages)

      return unless group.owned_by?(current_user)

      Notifications::TargetedMessageNamespace.by_namespace_for_user(group, current_user).pick(:targeted_message_id)
    end
  end
end
