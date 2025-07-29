# frozen_string_literal: true

module Projects
  module Security
    class ComplianceDashboardsController < Projects::ApplicationController
      feature_category :compliance_management

      before_action :ensure_feature_enabled!

      before_action do
        push_frontend_ability(ability: :admin_compliance_framework, resource: project, user: current_user)
      end

      def show; end

      private

      def ensure_feature_enabled!
        render_404 unless Ability.allowed?(current_user, :read_compliance_dashboard, project)
      end
    end
  end
end
