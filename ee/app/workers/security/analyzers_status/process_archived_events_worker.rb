# frozen_string_literal: true

module Security
  module AnalyzersStatus
    class ProcessArchivedEventsWorker
      include Gitlab::EventStore::Subscriber

      data_consistency :sticky
      idempotent!
      deduplicate :until_executing, including_scheduled: true

      feature_category :security_asset_inventories

      def handle_event(event)
        project_id = event.data[:project_id]
        namespace_id = event.data[:namespace_id]

        handle_project_related_records(project_id)
        handle_namespace_related_records(namespace_id)
      end

      def handle_project_related_records(project_id)
        project = Project.find_by_id(project_id)
        return unless project

        UpdateArchivedService.execute(project)
        handle_security_inventory_filters(project)
      end

      def handle_namespace_related_records(namespace_id)
        group = Group.find_by_id(namespace_id)
        return unless group.present?

        Security::AnalyzerNamespaceStatuses::RecalculateService.execute(group)
      end

      def handle_security_inventory_filters(project)
        Security::InventoryFilter.by_project_id(project.id).update(archived: project.archived)
      end
    end
  end
end
