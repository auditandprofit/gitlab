# frozen_string_literal: true

module Ai
  module KnowledgeGraph
    class Task < ApplicationRecord
      include ::Search::Zoekt::Taskable

      self.table_name = 'p_knowledge_graph_tasks'

      belongs_to :node, foreign_key: :zoekt_node_id, inverse_of: :knowledge_graph_tasks,
        class_name: '::Search::Zoekt::Node'
      belongs_to :knowledge_graph_replica, inverse_of: :tasks, class_name: '::Ai::KnowledgeGraph::Replica'

      scope :for_partition, ->(partition) { where(partition_id: partition) }
      scope :with_namespace, -> { includes(knowledge_graph_replica: { knowledge_graph_enabled_namespace: :namespace }) }
      scope :for_namespace, ->(namespace) { where(knowledge_graph_replica: namespace.replicas) }

      enum :task_type, {
        index_graph_repo: 0,
        delete_graph_repo: 50
      }

      before_validation :set_namespace_id

      validate :namespace_id_matches_replica_namespace_id

      def self.on_tasks_done(done_tasks)
        Ai::KnowledgeGraph::Replica
          .where(namespace_id: done_tasks.select(:namespace_id))
          .id_in(done_tasks.select(:knowledge_graph_replica_id))
          .update_all(state: :ready, updated_at: Time.current)
      end

      def self.task_iterator
        scope = processing_queue.with_namespace.order(:perform_at, :id)
        Gitlab::Pagination::Keyset::Iterator.new(scope: scope)
      end

      def self.determine_task_state(task)
        return :valid if task.delete_graph_repo?

        namespace = task.knowledge_graph_replica.knowledge_graph_enabled_namespace&.namespace
        return :orphaned unless namespace
        return :skipped unless Feature.enabled?(:knowledge_graph_indexing, namespace.project)

        unless Ai::KnowledgeGraph::Replica::INDEXABLE_STATES.include?(task.knowledge_graph_replica.state.to_sym)
          return :skipped
        end

        # Mark tasks as done since we have nothing to index
        return :done unless namespace.project.repo_exists?

        :valid
      end

      def per_batch_unique_id
        namespace_id
      end

      private

      def set_namespace_id
        self.namespace_id ||= knowledge_graph_replica&.namespace_id
      end

      def namespace_id_matches_replica_namespace_id
        return unless namespace_id.present?
        return unless knowledge_graph_replica
        return if namespace_id == knowledge_graph_replica.namespace_id

        errors.add(:namespace_id, :invalid)
      end
    end
  end
end
