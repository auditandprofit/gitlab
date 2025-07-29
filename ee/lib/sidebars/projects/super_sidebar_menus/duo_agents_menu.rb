# frozen_string_literal: true

module Sidebars
  module Projects
    module SuperSidebarMenus
      class DuoAgentsMenu < ::Sidebars::Menu
        override :configure_menu_items
        def configure_menu_items
          return false unless Feature.enabled?(:duo_workflow_in_ci, context.current_user)

          add_item(duo_agents_runs_menu_item)
          true
        end

        override :title
        def title
          s_('DuoAgentsPlatform|Automate')
        end

        override :sprite_icon
        def sprite_icon
          'tanuki-ai'
        end

        private

        def duo_agents_runs_menu_item
          ::Sidebars::MenuItem.new(
            title: s_('Agent sessions'),
            link: project_automate_agent_sessions_path(context.project),
            active_routes: { controller: :duo_agents_platform },
            item_id: :agents_runs
          )
        end
      end
    end
  end
end
