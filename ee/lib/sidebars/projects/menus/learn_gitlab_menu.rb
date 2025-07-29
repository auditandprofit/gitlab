# frozen_string_literal: true

module Sidebars
  module Projects
    module Menus
      class LearnGitlabMenu < ::Sidebars::Menu
        override :link
        def link
          project_learn_gitlab_path(context.project)
        end

        override :active_routes
        def active_routes
          { controller: :learn_gitlab }
        end

        override :title
        def title
          _('Learn GitLab')
        end

        override :has_pill?
        def has_pill?
          context.learn_gitlab_enabled
        end

        override :pill_count
        def pill_count
          percentage = ::Onboarding::Completion.new(
            context.project,
            context.current_user
          ).percentage

          "#{percentage}%"
        end

        override :sprite_icon
        def sprite_icon
          'bulb'
        end

        override :render?
        def render?
          context.learn_gitlab_enabled
        end

        # pill_count_dynamic signals to the frontend that the pill count value can be updated in realtime
        # by another javascript action using eventHub setup.
        # Things like the onboarding landing page of get started menu will use this as
        # a trigger to allow the pillData to be updated correctly.
        # Items like this won't use the graphql async process as we want to action to happen
        # immediately to reduce inconsistent UI state with other places in the page
        # that are updating via javascript.
        override :serialize_as_menu_item_args
        def serialize_as_menu_item_args
          super.merge({
            sprite_icon: sprite_icon,
            pill_count: pill_count,
            pill_count_dynamic: true,
            has_pill: has_pill?,
            super_sidebar_parent: ::Sidebars::StaticMenu,
            item_id: :learn_gitlab
          })
        end
      end
    end
  end
end
