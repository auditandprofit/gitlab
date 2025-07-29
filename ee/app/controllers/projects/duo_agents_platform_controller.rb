# frozen_string_literal: true

module Projects
  class DuoAgentsPlatformController < Projects::ApplicationController
    feature_category :duo_workflow
    before_action :check_access

    def show; end

    private

    def check_access
      render_404 unless ::Feature.enabled?(:duo_workflow_in_ci, current_user) && ::Ai::DuoWorkflow.enabled?
    end
  end
end
