# frozen_string_literal: true

module EE
  module Sidebars
    module Explore
      module Menus
        class DependenciesMenu < ::Sidebars::Menu
          override :link
          def link
            explore_dependencies_path
          end

          override :title
          def title
            _('Dependency list')
          end

          override :sprite_icon
          def sprite_icon
            'shield'
          end

          override :render?
          def render?
            current_user.present? &&
              ::Feature.enabled?(:explore_dependencies, current_user) &&
              current_user.can?(:read_dependency, current_organization)
          end

          override :active_routes
          def active_routes
            { controller: ['explore/dependencies'] }
          end

          private

          def current_organization
            context.current_organization
          end
        end
      end
    end
  end
end
