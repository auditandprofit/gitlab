# frozen_string_literal: true

module EE
  module Sidebars
    module Admin
      module Menus
        module AdminSettingsMenu
          include ::GitlabSubscriptions::SubscriptionHelper
          extend ::Gitlab::Utils::Override

          override :configure_menu_items
          def configure_menu_items
            return false unless super

            insert_item_after(:general_settings, service_accounts_menu_item)
            insert_item_after(:service_accounts, roles_and_permissions_menu_item)
            insert_item_after(:admin_reporting, templates_menu_item)
            insert_item_after(:admin_ci_cd, security_and_compliance_menu_item)
            insert_item_after(:security_and_compliance_menu_item, analytics_menu_item)
            insert_item_after(:admin_preferences, usage_quotas_menu_item)

            true
          end

          private

          def roles_and_permissions_menu_item
            return ::Sidebars::NilMenuItem.new(item_id: :roles_and_permissions) unless roles_and_permissions_available?

            ::Sidebars::MenuItem.new(
              title: _('Roles and permissions'),
              link: admin_application_settings_roles_and_permissions_path,
              active_routes: { controller: :roles_and_permissions },
              item_id: :roles_and_permissions
            )
          end

          def service_accounts_menu_item
            return ::Sidebars::NilMenuItem.new(item_id: :service_accounts) unless service_accounts_available?

            ::Sidebars::MenuItem.new(
              title: _('Service accounts'),
              link: admin_application_settings_service_accounts_path,
              active_routes: { controller: :service_accounts },
              item_id: :service_accounts
            )
          end

          def roles_and_permissions_available?
            return false unless can?(current_user, :view_member_roles)

            # In SaaS only custom admin roles are shown, so we need to check if the feature flag is enabled.
            gitlab_com_subscription? ? ::Feature.enabled?(:custom_admin_roles, :instance) : true
          end

          def service_accounts_available?
            can?(current_user, :admin_service_accounts) && !gitlab_com_subscription?
          end

          def templates_menu_item
            unless ::License.feature_available?(:custom_file_templates)
              return ::Sidebars::NilMenuItem.new(item_id: :admin_templates)
            end

            ::Sidebars::MenuItem.new(
              title: _('Templates'),
              link: templates_admin_application_settings_path,
              active_routes: { path: 'admin/application_settings#templates' },
              item_id: :admin_templates,
              container_html_options: { testid: 'admin-settings-templates-link' }
            )
          end

          def security_and_compliance_menu_item
            unless ::License.feature_available?(:license_scanning)
              return ::Sidebars::NilMenuItem.new(item_id: :admin_security_and_compliance)
            end

            ::Sidebars::MenuItem.new(
              title: _('Security and compliance'),
              link: security_and_compliance_admin_application_settings_path,
              active_routes: { path: 'admin/application_settings#security_and_compliance' },
              item_id: :admin_security_and_compliance,
              container_html_options: { testid: 'admin-security-and-compliance-link' }
            )
          end

          def analytics_menu_item
            unless ::License.feature_available?(:product_analytics) &&
                ::Feature.enabled?(:product_analytics_admin_settings, :instance)
              return ::Sidebars::NilMenuItem.new(item_id: :admin_analytics)
            end

            ::Sidebars::MenuItem.new(
              title: _('Analytics'),
              link: analytics_admin_application_settings_path,
              active_routes: { path: 'admin/application_settings#analytics' },
              item_id: :admin_analytics,
              container_html_options: { testid: 'admin-analytics-link' }
            )
          end

          def usage_quotas_menu_item
            return unless dedicated?

            ::Sidebars::MenuItem.new(
              title: _('Usage Quotas'),
              link: usage_quotas_admin_application_settings_path,
              active_routes: { path: 'admin/application_settings#usage_quotas' },
              item_id: :admin_usage_quotas,
              container_html_options: { 'data-testid': 'admin-settings-usage-quotas-link' }
            )
          end

          def dedicated?
            ::Gitlab::CurrentSettings.gitlab_dedicated_instance?
          end
        end
      end
    end
  end
end
