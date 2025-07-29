# frozen_string_literal: true

module EE
  module Projects
    module MergeRequestsController
      extend ActiveSupport::Concern

      prepended do
        include DescriptionDiffActions
        include GeoInstrumentation

        before_action only: [:show] do
          push_frontend_feature_flag(:merge_trains_skip_train, @project)
          push_frontend_ability(ability: :resolve_vulnerability_with_ai, resource: @project, user: current_user)
          push_frontend_ability(ability: :measure_comment_temperature, resource: merge_request, user: current_user)
        end

        before_action do
          push_frontend_feature_flag(:mr_reports_tab, @project)
        end

        before_action :authorize_read_pipeline!, only: [:metrics_reports]
        before_action :authorize_read_security_resource!, only: [
          :container_scanning_reports, :dependency_scanning_reports,
          :sast_reports, :secret_detection_reports,
          :dast_reports, :coverage_fuzzing_reports, :api_fuzzing_reports
        ]
        before_action :authorize_read_licenses!, only: [:license_scanning_reports, :license_scanning_reports_collapsed]

        before_action :authorize_read_security_reports!, only: [:security_reports]
        before_action :set_application_context!, only: [:show, :diffs, :commits, :pipelines]

        after_action :display_duo_seat_warning, only: [:update]

        feature_category :vulnerability_management, [:container_scanning_reports, :dependency_scanning_reports,
          :sast_reports, :secret_detection_reports, :dast_reports,
          :coverage_fuzzing_reports, :api_fuzzing_reports,
          :security_reports]
        feature_category :observability, [:metrics_reports]
        feature_category :software_composition_analysis,
          [:license_scanning_reports, :license_scanning_reports_collapsed]
        feature_category :code_review_workflow, [:delete_description_version, :description_diff, :reports]

        urgency :high, [:delete_description_version]
        urgency :low, [:container_scanning_reports,
          :dependency_scanning_reports, :sast_reports,
          :secret_detection_reports, :dast_reports,
          :coverage_fuzzing_reports, :api_fuzzing_reports,
          :metrics_reports, :description_diff,
          :license_scanning_reports, :license_scanning_reports_collapsed,
          :security_reports, :reports]

        def reports
          return render_404 unless ::Feature.enabled?(:mr_reports_tab, current_user, type: :wip)

          show_merge_request
        end
      end

      def can_run_sast_experiments_on?(project)
        project.licensed_feature_available?(:sast) &&
          project.feature_available?(:security_and_compliance, current_user)
      end

      def license_scanning_reports
        reports_response(merge_request.compare_license_scanning_reports(current_user))
      end

      def license_scanning_reports_collapsed
        reports_response(merge_request.compare_license_scanning_reports_collapsed(current_user))
      end

      def container_scanning_reports
        reports_response(merge_request.compare_container_scanning_reports(current_user), head_pipeline)
      end

      def dependency_scanning_reports
        reports_response(merge_request.compare_dependency_scanning_reports(current_user), head_pipeline)
      end

      def dast_reports
        reports_response(merge_request.compare_dast_reports(current_user), head_pipeline)
      end

      def metrics_reports
        reports_response(merge_request.compare_metrics_reports)
      end

      def coverage_fuzzing_reports
        reports_response(merge_request.compare_coverage_fuzzing_reports(current_user), head_pipeline)
      end

      def api_fuzzing_reports
        reports_response(merge_request.compare_api_fuzzing_reports(current_user), head_pipeline)
      end

      def security_reports
        report = ::Security::MergeRequestSecurityReportGenerationService.execute(merge_request, params[:type])

        reports_response(report, head_pipeline)
      rescue ::Security::MergeRequestSecurityReportGenerationService::InvalidReportTypeError
        head :bad_request
      end

      private

      def authorize_read_security_reports!
        return render_404 unless can?(current_user, :read_security_resource, merge_request.project)
      end
    end
  end
end
