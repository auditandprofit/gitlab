# frozen_string_literal: true

module Security
  module AnalyzersStatus
    class ProcessProjectTransferEventsWorker
      include Gitlab::EventStore::Subscriber

      idempotent!
      data_consistency :sticky
      feature_category :security_asset_inventories

      def handle_event(event)
        project = Project.find_by_id(event.data[:project_id])

        return unless project

        UpdateProjectAncestorsStatusesService.execute(project)
        project.analyzer_statuses.update_all(traversal_ids: project.namespace.traversal_ids)
        update_inventory_filter(project)
      end

      def update_inventory_filter(project)
        InventoryFilter.by_project_id(project.id).update(traversal_ids: project.namespace.traversal_ids)
      end
    end
  end
end
