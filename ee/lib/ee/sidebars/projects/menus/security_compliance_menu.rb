# frozen_string_literal: true

module EE
  module Sidebars
    module Projects
      module Menus
        module SecurityComplianceMenu
          extend ::Gitlab::Utils::Override

          override :configure_menu_items
          def configure_menu_items
            return false unless can_access_some_page?

            add_item(discover_project_security_menu_item)
            add_item(security_dashboard_menu_item)
            add_item(vulnerability_report_menu_item)
            add_item(on_demand_scans_menu_item)
            add_item(dependencies_menu_item)
            add_item(compliance_menu_item)
            add_item(scan_policies_menu_item)
            add_item(audit_events_menu_item)
            add_item(configuration_menu_item)
            add_item(secrets_manager_menu_item)

            true
          end

          private

          def can_access_some_page?
            context.project.feature_available?(:security_and_compliance, context.current_user)
          end

          def can_access_security_dashboard?
            can?(context.current_user, :access_security_and_compliance, context.project) &&
              can?(context.current_user, :read_project_security_dashboard, context.project)
          end

          def can_access_configuration?
            can?(context.current_user, :access_security_and_compliance, context.project) &&
              can?(context.current_user, :read_security_configuration, context.project)
          end

          def can_access_license?
            can?(context.current_user, :access_security_and_compliance, context.project) &&
              can?(context.current_user, :read_licenses, context.project)
          end

          def can_access_dependencies?
            can?(context.current_user, :access_security_and_compliance, context.project) &&
              can?(context.current_user, :read_dependency, context.project)
          end

          override :configuration_menu_item_paths
          def configuration_menu_item_paths
            super + %w[
              projects/security/sast_configuration#show
              projects/security/api_fuzzing_configuration#show
              projects/security/dast_configuration#show
              projects/security/dast_profiles#show
              projects/security/dast_site_profiles#new
              projects/security/dast_site_profiles#edit
              projects/security/dast_scanner_profiles#new
              projects/security/dast_scanner_profiles#edit
              projects/security/corpus_management#show
              projects/security/secret_detection_configuration#show
            ]
          end

          override :render_configuration_menu_item?
          def render_configuration_menu_item?
            super || can_access_configuration?
          end

          def discover_project_security_menu_item
            unless context.show_discover_project_security
              return ::Sidebars::NilMenuItem.new(item_id: :discover_project_security)
            end

            ::Sidebars::MenuItem.new(
              title: _('Security capabilities'),
              link: project_security_discover_path(context.project),
              super_sidebar_parent: ::Sidebars::Projects::SuperSidebarMenus::SecureMenu,
              active_routes: { path: 'projects/security/discover#show' },
              item_id: :discover_project_security
            )
          end

          def security_dashboard_menu_item
            unless can_access_security_dashboard?
              return ::Sidebars::NilMenuItem.new(item_id: :dashboard)
            end

            ::Sidebars::MenuItem.new(
              title: _('Security dashboard'),
              link: project_security_dashboard_index_path(context.project),
              super_sidebar_parent: ::Sidebars::Projects::SuperSidebarMenus::SecureMenu,
              active_routes: { path: 'projects/security/dashboard#index' },
              item_id: :dashboard
            )
          end

          def vulnerability_report_menu_item
            unless can?(context.current_user, :read_security_resource, context.project)
              return ::Sidebars::NilMenuItem.new(item_id: :vulnerability_report)
            end

            ::Sidebars::MenuItem.new(
              title: _('Vulnerability report'),
              link: project_security_vulnerability_report_index_path(context.project),
              super_sidebar_parent: ::Sidebars::Projects::SuperSidebarMenus::SecureMenu,
              active_routes: {
                path: %w[
                  projects/security/vulnerability_report#index
                  projects/security/vulnerabilities#show
                  projects/security/vulnerabilities#new
                ]
              },
              item_id: :vulnerability_report
            )
          end

          def on_demand_scans_menu_item
            unless context.project.on_demand_dast_available?
              return ::Sidebars::NilMenuItem.new(item_id: :on_demand_scans)
            end

            unless can?(context.current_user, :read_on_demand_dast_scan, context.project)
              return ::Sidebars::NilMenuItem.new(item_id: :on_demand_scans)
            end

            link = project_on_demand_scans_path(context.project)

            ::Sidebars::MenuItem.new(
              title: s_('OnDemandScans|On-demand scans'),
              link: link,
              super_sidebar_parent: ::Sidebars::Projects::SuperSidebarMenus::SecureMenu,
              item_id: :on_demand_scans,
              active_routes: { path: %w[
                projects/on_demand_scans#index
                projects/on_demand_scans#new
                projects/on_demand_scans#edit
              ] }
            )
          end

          def dependencies_menu_item
            unless can_access_dependencies?
              return ::Sidebars::NilMenuItem.new(item_id: :dependency_list)
            end

            ::Sidebars::MenuItem.new(
              title: _('Dependency list'),
              link: project_dependencies_path(context.project),
              super_sidebar_parent: ::Sidebars::Projects::SuperSidebarMenus::SecureMenu,
              active_routes: { path: 'projects/dependencies#index' },
              item_id: :dependency_list
            )
          end

          def secrets_manager_menu_item
            unless ::Feature.enabled?(:ci_tanukey_ui, context.project) &&
                SecretsManagement::ProjectSecretsManager.find_by_project_id(context.project)
              return ::Sidebars::NilMenuItem.new(item_id: :secrets_manager)
            end

            ::Sidebars::MenuItem.new(
              title: _('Secrets manager'),
              link: project_secrets_path(context.project),
              super_sidebar_parent: ::Sidebars::Projects::SuperSidebarMenus::SecureMenu,
              active_routes: { path: 'projects/secrets' },
              item_id: :secrets_manager
            )
          end

          def scan_policies_menu_item
            unless can?(context.current_user, :read_security_orchestration_policies, context.project)
              return ::Sidebars::NilMenuItem.new(item_id: :scan_policies)
            end

            ::Sidebars::MenuItem.new(
              title: _('Policies'),
              link: project_security_policies_path(context.project),
              super_sidebar_parent: ::Sidebars::Projects::SuperSidebarMenus::SecureMenu,
              active_routes: { controller: ['projects/security/policies'] },
              item_id: :scan_policies
            )
          end

          def compliance_menu_item
            unless project_level_compliance_dashboard_available?
              return ::Sidebars::NilMenuItem.new(item_id: :compliance)
            end

            ::Sidebars::MenuItem.new(
              title: _('Compliance center'),
              link: project_security_compliance_dashboard_path(context.project),
              super_sidebar_parent: ::Sidebars::Projects::SuperSidebarMenus::SecureMenu,
              active_routes: { path: 'compliance_dashboards#show' },
              item_id: :compliance
            )
          end

          def audit_events_menu_item
            unless show_audit_events?
              return ::Sidebars::NilMenuItem.new(item_id: :audit_events)
            end

            ::Sidebars::MenuItem.new(
              title: _('Audit events'),
              link: project_audit_events_path(context.project),
              super_sidebar_parent: ::Sidebars::Projects::SuperSidebarMenus::SecureMenu,
              active_routes: { controller: :audit_events },
              item_id: :audit_events
            )
          end

          def show_audit_events?
            can?(context.current_user, :read_project_audit_events, context.project) &&
              (context.project.licensed_feature_available?(:audit_events) || context.show_promotions)
          end

          def project_level_compliance_dashboard_available?
            can?(context.current_user, :read_compliance_dashboard, context.project)
          end
        end
      end
    end
  end
end
