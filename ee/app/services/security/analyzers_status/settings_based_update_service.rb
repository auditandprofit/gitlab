# frozen_string_literal: true

module Security
  module AnalyzersStatus
    class SettingsBasedUpdateService
      include ::Security::AnalyzersStatus::AggregatedTypesHandler

      TooManyProjectIdsError = Class.new(StandardError)
      MAX_PROJECT_IDS = Security::AnalyzersStatus::ScheduleSettingChangedUpdateWorker::BATCH_SIZE

      def self.execute(project_ids, analyzer_type)
        new(project_ids, analyzer_type).execute
      end

      def initialize(project_ids, analyzer_type)
        if project_ids && project_ids.size > MAX_PROJECT_IDS
          raise TooManyProjectIdsError, "Cannot update analyzer statuses of more than #{MAX_PROJECT_IDS} projects"
        end

        @project_ids = project_ids
        @analyzer_type = analyzer_type.to_sym
      end

      def execute
        return unless TYPE_MAPPINGS[analyzer_type].present? && projects.present?

        namespaces_diffs = DiffsService.new(analyzers_statuses).execute
        upsert_analyzers_statuses
        update_ancestors(namespaces_diffs)
      end

      private

      attr_reader :project_ids, :analyzer_type

      def projects
        return [] unless project_ids.present?

        @projects ||= begin
          unfiltered_projects = Project.id_in(project_ids).with_security_setting.with_namespaces.with_analyzer_statuses
          filter_feature_enabled_projects(unfiltered_projects)
        end
      end

      def analyzers_statuses
        @analyzers_statuses ||= projects.each_with_object({}) do |project, memo|
          setting_field = TYPE_MAPPINGS[@analyzer_type][:setting_field]
          setting_enabled = project.security_setting&.read_attribute(setting_field) || false
          setting_status = status_to_symbol(setting_enabled)
          setting_type = TYPE_MAPPINGS[@analyzer_type][:setting_type]

          aggregated_status =
            build_aggregated_type_status(project, TYPE_MAPPINGS[@analyzer_type][:setting_type],
              { status: setting_status })

          memo[project] = {
            setting_type => build_analyzer_status_hash(project, setting_type, setting_status)
          }.tap do |hash|
            hash[aggregated_status[:analyzer_type]] = aggregated_status if aggregated_status
          end
        end
      end

      def upsert_analyzers_statuses
        statuses_array = analyzers_statuses.values.flat_map(&:values)
        return unless statuses_array.present?

        AnalyzerProjectStatus.upsert_all(statuses_array, unique_by: [:project_id, :analyzer_type])
      end

      def status_to_symbol(status)
        status ? :success : :not_configured
      end

      def update_ancestors(namespaces_diffs)
        return unless namespaces_diffs.present?

        namespaces_diffs.each do |namespace_diffs|
          Security::AnalyzerNamespaceStatuses::AncestorsUpdateService.execute(namespace_diffs)
        end
      end

      def filter_feature_enabled_projects(projects)
        # Validate the feature flag once per root ancestor
        projects
          .group_by(&:root_ancestor)
          .select { |root_ancestor, _| Feature.enabled?(:group_settings_based_update_worker, root_ancestor) }
          .values.flatten
      end
    end
  end
end
