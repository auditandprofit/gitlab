# frozen_string_literal: true

module Projects
  class SecretsController < Projects::ApplicationController
    feature_category :secrets_management
    urgency :low, [:index]

    layout 'project'

    before_action :authorize_view_secrets!
    before_action :check_secrets_enabled!

    private

    def authorize_view_secrets!
      render_404 unless can?(current_user, :developer_access, project)
    end

    def check_secrets_enabled!
      render_404 unless
        Feature.enabled?(:ci_tanukey_ui, project) &&
          SecretsManagement::ProjectSecretsManager.find_by_project_id(@project.id)
    end
  end
end
