# frozen_string_literal: true

module Projects
  module Security
    class ComplianceViolationsController < Projects::ApplicationController
      feature_category :compliance_management

      before_action :authorize_view_violations!
      before_action :check_violations_report_enabled!

      def show; end

      private

      def authorize_view_violations!
        render_404 unless project.licensed_feature_available?(:project_level_compliance_dashboard) &&
          can?(current_user, :read_compliance_dashboard, project)
      end

      def check_violations_report_enabled!
        render_404 unless Feature.enabled?(:compliance_violations_report, project.root_ancestor)
      end
    end
  end
end
