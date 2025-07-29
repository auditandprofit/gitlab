# frozen_string_literal: true

module Ai
  module KnowledgeGraph
    class IndexingTaskWorker
      include ApplicationWorker
      prepend ::Geo::SkipSecondary

      data_consistency :delayed
      idempotent!
      urgency :low
      feature_category :knowledge_graph

      concurrency_limit -> { 2_000 }

      defer_on_database_health_signal :gitlab_main, [:zoekt_nodes, :zoekt_indices, :zoekt_tasks], 10.minutes

      def perform(namespace_id, task_type)
        response = Ai::KnowledgeGraph::IndexingTaskService.new(namespace_id, task_type).execute
        return unless response.error?

        logger.error(
          structured_payload(message: response.message, reason: response.reason, namespace_id: namespace_id)
        )
      end
    end
  end
end
