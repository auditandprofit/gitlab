# frozen_string_literal: true

module Sidebars # rubocop:disable Gitlab/BoundedContexts -- Existing module
  module Admin
    module Menus
      class TargetedMessagesMenu < ::Sidebars::Admin::BaseMenu
        override :link
        def link
          admin_targeted_messages_path
        end

        override :title
        def title
          s_('Admin|Targeted messages')
        end

        override :sprite_icon
        def sprite_icon
          'messages'
        end

        override :render?
        def render?
          Feature.enabled?(:targeted_messages_admin_ui, :instance) &&
            ::Gitlab::Saas.feature_available?(:targeted_messages) &&
            !!context.current_user&.can_admin_all_resources?
        end

        override :active_routes
        def active_routes
          { controller: :targeted_messages }
        end
      end
    end
  end
end
