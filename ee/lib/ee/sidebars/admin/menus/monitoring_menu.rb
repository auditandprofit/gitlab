# frozen_string_literal: true

module EE
  module Sidebars
    module Admin
      module Menus
        module MonitoringMenu
          extend ::Gitlab::Utils::Override

          override :configure_menu_items
          def configure_menu_items
            return false unless super

            insert_item_after(:health_check, audit_events_menu_item)

            true
          end

          override :render_with_abilities
          def render_with_abilities
            super + %i[read_admin_system_information]
          end

          private

          def audit_events_menu_item
            build_menu_item(
              title: _('Audit events'),
              link: admin_audit_logs_path,
              active_routes: { path: 'admin/audit_logs#index' },
              item_id: :audit_logs,
              container_html_options: { testid: 'admin-monitoring-audit-logs-link' }
            ) do
              ::License.feature_available?(:admin_audit_log) &&
                can?(current_user, :read_admin_audit_log)
            end
          end
        end
      end
    end
  end
end
