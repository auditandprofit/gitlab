# frozen_string_literal: true

module Projects
  module Security
    class VulnerabilitiesController < Projects::ApplicationController
      include IssuableActions
      include GovernUsageProjectTracking

      before_action :vulnerability, except: [:new]
      before_action :authorize_admin_vulnerability!, except: [:show, :discussions]
      before_action :authorize_read_vulnerability!, except: [:new]

      before_action do
        push_frontend_feature_flag(:vulnerability_report_type_scanner_filter, project)
        push_frontend_feature_flag(:hide_vulnerability_severity_override, project)
        push_frontend_feature_flag(:validity_checks, project)
        push_frontend_feature_flag(:validity_refresh, project)
      end

      alias_method :vulnerable, :project

      feature_category :vulnerability_management
      urgency :low
      track_govern_activity 'security_vulnerabilities', :show

      def show
        push_frontend_ability(ability: :explain_vulnerability_with_ai, resource: vulnerability, user: current_user)
        push_frontend_ability(ability: :resolve_vulnerability_with_ai, resource: vulnerability, user: current_user)
        push_frontend_feature_flag(:dependency_paths, project)

        pipeline = vulnerability.finding.first_finding_pipeline
        @pipeline = pipeline if can?(current_user, :read_pipeline, pipeline)
        @gfm_form = true
      end

      private

      def vulnerability
        @issuable = @noteable = @vulnerability ||= vulnerable.vulnerabilities.find(params.permit(:id)[:id])
      end

      alias_method :issuable, :vulnerability
      alias_method :noteable, :vulnerability

      def issue_serializer
        IssueSerializer.new(current_user: current_user)
      end
    end
  end
end
