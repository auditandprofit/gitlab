# frozen_string_literal: true

module Search
  module Zoekt
    class TaskPresenterService
      include Gitlab::Loggable

      attr_reader :node, :concurrency_limit

      def self.execute(...)
        new(...).execute
      end

      def initialize(node)
        @node = node
        @concurrency_limit = node.concurrency_limit
      end

      def execute
        delete_only = node.watermark_exceeded_critical?
        if delete_only
          logger.warn(build_structured_payload(
            message: 'Node watermark exceeded critical threshold. Only presenting delete tasks',
            meta: node.metadata_json
          ))
        end

        # Return both knowledge graph and zoekt tasks in the batch, knowledge graph tasks take half of the batch at max.
        # When there are only knowledge graph tasks, then currently only half of the capacity is used. This is fine for
        # now but we could refactor `each_task_for_processing` iterator to use full capacity of the batch.
        [].tap do |payload|
          knowledge_graph_tasks(delete_only).each_task_for_processing(limit: concurrency_limit / 2) do |task|
            payload << TaskSerializerService.execute(task, node)
          end

          zoekt_tasks(delete_only).each_task_for_processing(limit: concurrency_limit - payload.size) do |task|
            payload << TaskSerializerService.execute(task, node)
          end
        end
      end

      def zoekt_tasks(delete_only)
        rel = node.tasks
        return rel.none if ::Gitlab::CurrentSettings.zoekt_indexing_paused?
        return rel.delete_repo if delete_only

        rel
      end

      def knowledge_graph_tasks(delete_only)
        rel = node.knowledge_graph_tasks
        return rel.delete_graph_repo if delete_only

        rel
      end

      def logger
        @logger ||= ::Search::Zoekt::Logger.build
      end
    end
  end
end
