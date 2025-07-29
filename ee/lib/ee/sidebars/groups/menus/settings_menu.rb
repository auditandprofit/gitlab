# frozen_string_literal: true

module EE
  module Sidebars
    module Groups
      module Menus
        module SettingsMenu
          extend ::Gitlab::Utils::Override
          include ::GitlabSubscriptions::SubscriptionHelper
          include ::Groups::AnalyticsDashboardHelper
          include ::Nav::GitlabDuoSettingsPage

          override :configure_menu_items
          def configure_menu_items
            super

            if can?(context.current_user, :read_web_hook, context.group)
              insert_item_after(:integrations, webhooks_menu_item)
            end

            if can?(context.current_user, :admin_group, context.group)
              insert_item_after(:general, service_accounts_menu_item)
              insert_item_after(:service_accounts, roles_and_permissions_menu_item)
              insert_item_after(:group_projects, group_work_items_menu_item)
              insert_item_after(:ci_cd, analytics_menu_item)
              insert_item_after(:usage_quotas, gitlab_duo_settings_menu_item)
              add_item(ldap_sync_menu_item)
              add_item(saml_sso_menu_item)
              add_item(saml_group_links_menu_item)
              add_item(domain_verification_menu_item)
              add_item(billing_menu_item)
              add_item(reporting_menu_item)
              add_item(workspaces_menu_item)
            else
              add_menu_item_for_abilities(general_menu_item, [:remove_group, :admin_compliance_framework,
                :manage_merge_request_settings])
              add_menu_item_for_abilities(integrations_menu_item, :admin_integrations)
              add_menu_item_for_abilities(access_tokens_menu_item, :read_resource_access_tokens)
              add_item(group_work_items_menu_item)
              add_menu_item_for_abilities(repository_menu_item, [:admin_push_rules, :manage_deploy_tokens])
              add_menu_item_for_abilities(ci_cd_menu_item, [:admin_cicd_variables,
                :admin_protected_environments, :admin_runners])
              add_menu_item_for_abilities(billing_menu_item, :read_billing)
              add_menu_item_for_abilities(workspaces_menu_item, :read_namespace_cluster_agent_mapping)
            end
          end

          private

          def add_menu_item_for_abilities(menu_item, abilities)
            add_item(menu_item) if can_any?(context.current_user, Array(abilities), context.group)
          end

          def service_accounts_menu_item
            return ::Sidebars::NilMenuItem.new(item_id: :service_accounts) unless service_accounts_available?

            ::Sidebars::MenuItem.new(
              title: _('Service accounts'),
              link: group_settings_service_accounts_path(context.group),
              active_routes: { controller: :service_accounts },
              item_id: :service_accounts
            )
          end

          def roles_and_permissions_menu_item
            return ::Sidebars::NilMenuItem.new(item_id: :roles_and_permissions) unless custom_roles_enabled?

            ::Sidebars::MenuItem.new(
              title: _('Roles and permissions'),
              link: group_settings_roles_and_permissions_path(context.group),
              active_routes: { controller: :roles_and_permissions },
              item_id: :roles_and_permissions
            )
          end

          def service_accounts_available?
            context.group.root? &&
              can?(context.current_user, :create_service_account, context.group) &&
              can?(context.current_user, :delete_service_account, context.group)
          end

          def custom_roles_enabled?
            context.group.root? &&
              can?(context.current_user, :view_member_roles, context.group) &&
              gitlab_com_subscription?
          end

          def ldap_sync_menu_item
            return ::Sidebars::NilMenuItem.new(item_id: :ldap_sync) unless ldap_sync_enabled?

            ::Sidebars::MenuItem.new(
              title: _('LDAP Synchronization'),
              link: group_ldap_group_links_path(context.group),
              active_routes: { path: 'ldap_group_links#index' },
              item_id: :ldap_sync
            )
          end

          def ldap_sync_enabled?
            ::Gitlab::Auth::Ldap::Config.group_sync_enabled? &&
              can?(context.current_user, :admin_ldap_group_links, context.group)
          end

          def saml_sso_menu_item
            return ::Sidebars::NilMenuItem.new(item_id: :saml_sso) unless saml_sso_enabled?

            ::Sidebars::MenuItem.new(
              title: _('SAML SSO'),
              link: group_saml_providers_path(context.group),
              active_routes: { path: %w[saml_providers#show saml_providers#update] },
              item_id: :saml_sso
            )
          end

          def saml_sso_enabled?
            can?(context.current_user, :admin_group_saml, context.group)
          end

          def saml_group_links_menu_item
            return ::Sidebars::NilMenuItem.new(item_id: :saml_group_links) unless
              can?(context.current_user, :admin_saml_group_links, context.group)

            ::Sidebars::MenuItem.new(
              title: s_('GroupSAML|SAML Group Links'),
              link: group_saml_group_links_path(context.group),
              active_routes: { path: 'saml_group_links#index' },
              item_id: :saml_group_links
            )
          end

          def domain_verification_menu_item
            return ::Sidebars::NilMenuItem.new(item_id: :domain_verification) unless domain_verification_available?

            ::Sidebars::MenuItem.new(
              title: _('Domain Verification'),
              link: group_settings_domain_verification_index_path(context.group),
              active_routes: { controller: :domain_verification },
              item_id: :domain_verification
            )
          end

          def domain_verification_available?
            can?(context.current_user, :admin_group, context.group) && context.group.domain_verification_available?
          end

          def webhooks_menu_item
            return ::Sidebars::NilMenuItem.new(item_id: :webhooks) unless webhooks_enabled?

            ::Sidebars::MenuItem.new(
              title: _('Webhooks'),
              link: group_hooks_path(context.group),
              active_routes: { path: 'hooks#index' },
              item_id: :webhooks
            )
          end

          def webhooks_enabled?
            context.group.licensed_feature_available?(:group_webhooks) ||
              context.show_promotions
          end

          def billing_menu_item
            return ::Sidebars::NilMenuItem.new(item_id: :billing) unless billing_enabled?

            ::Sidebars::MenuItem.new(
              title: _('Billing'),
              link: group_billings_path(context.group),
              active_routes: { path: 'billings#index' },
              item_id: :billing
            )
          end

          def billing_enabled?
            ::Gitlab::CurrentSettings.should_check_namespace_plan?
          end

          def reporting_menu_item
            return ::Sidebars::NilMenuItem.new(item_id: :reporting) unless
              context.group.unique_project_download_limit_enabled?

            ::Sidebars::MenuItem.new(
              title: s_('GroupSettings|Reporting'),
              link: group_settings_reporting_path(context.group),
              active_routes: { path: 'reporting#show' },
              item_id: :reporting
            )
          end

          def workspaces_menu_item
            return ::Sidebars::NilMenuItem.new(item_id: :workspaces) unless workspaces_enabled?

            ::Sidebars::MenuItem.new(
              title: s_('Workspaces'),
              link: group_settings_workspaces_path(context.group),
              active_routes: { path: 'groups/settings/remote_development/workspaces#show' },
              item_id: :workspaces_settings
            )
          end

          def workspaces_enabled?
            can?(context.current_user, :access_workspaces_feature)
          end

          def analytics_menu_item
            return ::Sidebars::NilMenuItem.new(item_id: :analytics) unless analytics_available?

            ::Sidebars::MenuItem.new(
              title: _('Analytics'),
              link: group_settings_analytics_path(context.group),
              active_routes: { path: %w[analytics#show] },
              item_id: :analytics
            )
          end

          def analytics_available?
            group_analytics_settings_available?(context.current_user, context.group)
          end

          def gitlab_duo_settings_menu_item
            unless show_gitlab_duo_settings_menu_item?(context.group)
              return ::Sidebars::NilMenuItem.new(item_id: :gitlab_duo_settings)
            end

            ::Sidebars::MenuItem.new(
              title: _('GitLab Duo'),
              link: group_settings_gitlab_duo_path(context.group),
              active_routes: { path: ['configuration#index, seat_utilization#index', 'gitlab_duo#show'] },
              item_id: :gitlab_duo_settings
            )
          end

          def group_work_items_menu_item
            unless show_group_work_items_settings_menu_item?
              return ::Sidebars::NilMenuItem.new(item_id: :group_work_items_settings)
            end

            ::Sidebars::MenuItem.new(
              title: _('Issues'),
              link: group_settings_issues_path(context.group),
              active_routes: { controller: 'groups/settings/work_items' },
              item_id: :group_work_items_settings
            )
          end

          def show_group_work_items_settings_menu_item?
            context.group.root? &&
              context.group.licensed_feature_available?(:custom_fields) &&
              can?(context.current_user, :admin_custom_field, context.group)
          end
        end
      end
    end
  end
end
