# frozen_string_literal: true

module EE
  module Sidebars
    module UserSettings
      module Menus
        module AccessTokensMenu
          extend ::Gitlab::Utils::Override

          override :render?
          def render?
            return false if context.current_user&.enterprise_group&.disable_personal_access_tokens?

            super
          end
        end
      end
    end
  end
end
