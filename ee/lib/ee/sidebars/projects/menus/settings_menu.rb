# frozen_string_literal: true

module EE
  module Sidebars
    module Projects
      module Menus
        module SettingsMenu
          extend ::Gitlab::Utils::Override

          PERMITTABLE_MENU_ITEMS = {
            general_menu_item: [
              :view_edit_page
            ],
            access_tokens_menu_item: [
              :manage_resource_access_tokens
            ],
            repository_menu_item: [
              :admin_push_rules,
              :manage_deploy_tokens,
              :admin_protected_branch,
              :manage_protected_tags
            ],
            merge_requests_menu_item: [
              :manage_merge_request_settings
            ],
            ci_cd_menu_item: [
              :admin_cicd_variables,
              :admin_protected_environments,
              :admin_runners
            ],
            integrations_menu_item: [
              :admin_integrations
            ],
            webhooks_menu_item: [
              :read_web_hook
            ]
          }.freeze

          override :configure_menu_items
          def configure_menu_items
            return false unless super

            insert_item_after(:monitor, analytics_menu_item)

            true
          end

          def analytics_menu_item
            unless product_analytics_settings_allowed?(context.project)
              return ::Sidebars::NilMenuItem.new(item_id: :analytics)
            end

            ::Sidebars::MenuItem.new(
              title: _('Analytics'),
              link: project_settings_analytics_path(context.project),
              active_routes: { path: %w[projects/settings/analytics#show] },
              item_id: :analytics
            )
          end

          private

          override :enabled_menu_items
          def enabled_menu_items
            return super if can?(context.current_user, :admin_project, context.project)

            custom_roles_menu_items
          end

          alias_method :build, :send

          def custom_roles_menu_items
            return [] if context.current_user.blank?

            PERMITTABLE_MENU_ITEMS.filter_map do |(menu_item, permissions)|
              build(menu_item) if can_any?(context.current_user, permissions, context.project)
            end
          end
        end
      end
    end
  end
end
