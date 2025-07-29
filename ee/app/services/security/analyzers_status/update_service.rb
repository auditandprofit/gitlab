# frozen_string_literal: true

module Security
  module AnalyzersStatus
    class UpdateService
      include ::Security::AnalyzersStatus::AggregatedTypesHandler

      BUILD_TO_ANALYZER_STATUS = {
        "success" => :success,
        "failed" => :failed,
        "canceled" => :failed,
        "skipped" => :failed
      }.freeze

      PIPELINE_EXCLUDED_TYPES = %w[secret_detection secret_detection_secret_push_protection
        container_scanning container_scanning_for_registry].freeze

      def initialize(pipeline)
        @pipeline = pipeline
        @project = pipeline&.project
      end

      def execute
        return unless executable?

        status_diff = DiffService.new(project, analyzers_statuses).execute
        upsert_analyzers_statuses
        update_ancestors(status_diff)

      rescue StandardError => error
        Gitlab::ErrorTracking.track_exception(error, project_id: project.id, pipeline_id: pipeline.id)
      end

      private

      attr_reader :pipeline, :project

      def executable?
        return unless pipeline.present? && project.present?

        Feature.enabled?(:post_pipeline_analyzer_status_updates, project.root_ancestor)
      end

      def pipeline_builds
        @pipeline_builds ||= ::Security::SecurityJobsFinder.new(pipeline: pipeline)
          .execute
          .with_statuses(Ci::HasStatus::COMPLETED_STATUSES)
          .to_a
      end

      def analyzers_statuses
        @analyzers_statuses ||= begin
          pipeline_based = pipeline_based_analyzers_statuses
          not_configured = not_configured_statuses(pipeline_based)
          aggregated_statuses = aggregated_statuses(pipeline_based.merge(not_configured))

          pipeline_based.merge(not_configured).merge(aggregated_statuses)
        end
      end

      def pipeline_based_analyzers_statuses
        pipeline_builds.each_with_object({}) do |build, memo|
          build_analyzer_groups = analyzer_groups_from_build(build)
          status = BUILD_TO_ANALYZER_STATUS[build.status] || :not_configured

          build_analyzer_groups.each do |build_analyzer_group|
            if status_priority(status) > status_priority(memo[build_analyzer_group]&.[](:status))
              memo[build_analyzer_group] =
                build_analyzer_status_hash(project, build_analyzer_group, status, build: build)
            end
          end
        end
      end

      def analyzer_groups_from_build(build)
        report_artifacts = build_reports(build)
        existing_group_types = report_artifacts & Enums::Security.extended_analyzer_types.keys
        normalize_sast_types = normalize_sast_analyzers(build, existing_group_types)
        normalize_aggregated_types(normalize_sast_types)
      end

      def not_configured_statuses(analyzers_statuses)
        excluded_types = PIPELINE_EXCLUDED_TYPES + (analyzers_statuses.present? ? analyzers_statuses.keys : [])
        AnalyzerProjectStatus.by_projects(project).without_types(excluded_types).select(:analyzer_type)
          .each_with_object({}) do |record, memo|
          analyzer_type = record.analyzer_type.to_sym
          memo[analyzer_type] = build_analyzer_status_hash(project, analyzer_type, :not_configured)
        end
      end

      def normalize_sast_analyzers(build, existing_group_types)
        return existing_group_types unless existing_group_types.include?(:sast)

        # Because :sast_iac and :sast_advanced reports belong to a report with a name of 'sast',
        # we have to do extra checking to determine which reports have been included
        existing_group_types.push(:sast_advanced) if build.name == 'gitlab-advanced-sast'

        # kics-iac-sast is being treated as IaC and not as SAST
        if build.name == 'kics-iac-sast'
          existing_group_types.push(:sast_iac)
          existing_group_types.delete(:sast)
        end

        existing_group_types
      end

      def normalize_aggregated_types(existing_group_types)
        TYPE_MAPPINGS.each do |type, config|
          if existing_group_types.include?(type)
            existing_group_types.delete(type)
            existing_group_types.push(config[:pipeline_type])
          end
        end

        existing_group_types
      end

      def aggregated_statuses(analyzers_statuses)
        TYPE_MAPPINGS.values.each_with_object({}) do |config, memo|
          pipeline_type = config[:pipeline_type]
          next unless analyzers_statuses[pipeline_type]

          aggregated_status =
            build_aggregated_type_status(project, pipeline_type, analyzers_statuses[pipeline_type])
          memo[aggregated_status[:analyzer_type]] = aggregated_status if aggregated_status
        end
      end

      def upsert_analyzers_statuses
        return unless analyzers_statuses.present?

        AnalyzerProjectStatus.upsert_all(analyzers_statuses.values, unique_by: [:project_id, :analyzer_type])
      end

      def build_reports(build)
        build.options[:artifacts][:reports].keys
      end

      def update_ancestors(status_diff)
        Security::AnalyzerNamespaceStatuses::AncestorsUpdateService.execute(status_diff)
      end
    end
  end
end
