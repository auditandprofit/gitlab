# frozen_string_literal: true

module Groups
  module Settings
    module GitlabDuo
      class ConfigurationController < Groups::ApplicationController
        feature_category :ai_abstraction_layer

        include ::Nav::GitlabDuoSettingsPage

        def index
          redirect_to group_settings_gitlab_duo_path(group) unless render_configuration_page?
        end

        private

        def render_configuration_page?
          show_gitlab_duo_settings_menu_item?(group)
        end
      end
    end
  end
end
