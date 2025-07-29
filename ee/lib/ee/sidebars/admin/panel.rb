# frozen_string_literal: true

module EE
  module Sidebars
    module Admin
      module Panel
        include ::GitlabSubscriptions::CodeSuggestionsHelper
        extend ::Gitlab::Utils::Override

        override :configure_menus
        def configure_menus
          super

          insert_menu_before(
            ::Sidebars::Admin::Menus::DeployKeysMenu,
            ::Sidebars::Admin::Menus::PushRulesMenu.new(context)
          )

          insert_menu_before(
            ::Sidebars::Admin::Menus::DeployKeysMenu,
            ::Sidebars::Admin::Menus::GeoMenu.new(context)
          )

          insert_menu_before(
            ::Sidebars::Admin::Menus::LabelsMenu,
            ::Sidebars::Admin::Menus::CredentialsMenu.new(context)
          )

          insert_menu_after(
            ::Sidebars::Admin::Menus::AbuseReportsMenu,
            ::Sidebars::Admin::Menus::SubscriptionMenu.new(context)
          )

          insert_gitlab_duo_menu

          insert_menu_after(
            ::Sidebars::Admin::Menus::MessagesMenu,
            ::Sidebars::Admin::Menus::TargetedMessagesMenu.new(context)
          )
        end

        private

        def insert_gitlab_duo_menu
          return unless License.current&.paid?

          insert_menu_after(
            ::Sidebars::Admin::Menus::SubscriptionMenu,
            ::Sidebars::Admin::Menus::DuoSettingsMenu.new(context)
          )
        end
      end
    end
  end
end
