# frozen_string_literal: true

module EE
  module Sidebars
    module Groups
      module Panel
        extend ::Gitlab::Utils::Override

        override :configure_menus
        def configure_menus
          super

          if ::Feature.enabled?(:work_item_planning_view, context.group)
            insert_menu_after(
              context.is_super_sidebar ? ::Sidebars::Groups::Menus::SettingsMenu : ::Sidebars::Groups::Menus::GroupInformationMenu,
              ::Sidebars::Groups::Menus::WorkItemEpicsMenu.new(context)
            )
          else
            insert_menu_after(
              context.is_super_sidebar ? ::Sidebars::Groups::Menus::SettingsMenu : ::Sidebars::Groups::Menus::GroupInformationMenu,
              ::Sidebars::Groups::Menus::EpicsMenu.new(context)
            )
          end

          insert_menu_after(
            context.is_super_sidebar ? ::Sidebars::Groups::Menus::CiCdMenu : ::Sidebars::Groups::Menus::MergeRequestsMenu,
            ::Sidebars::Groups::Menus::SecurityComplianceMenu.new(context)
          )
          insert_menu_after(::Sidebars::Groups::Menus::PackagesRegistriesMenu, ::Sidebars::Groups::Menus::AnalyticsMenu.new(context))
          insert_menu_after(::Sidebars::Groups::Menus::AnalyticsMenu, ::Sidebars::Groups::Menus::WikiMenu.new(context))
        end
      end
    end
  end
end
