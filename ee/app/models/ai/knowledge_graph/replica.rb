# frozen_string_literal: true

module Ai
  module KnowledgeGraph
    class Replica < ApplicationRecord
      include PartitionedTable

      self.table_name = 'p_knowledge_graph_replicas'

      PARTITION_SIZE = 2_000_000
      INDEXABLE_STATES = %i[pending initializing ready].freeze
      RETRIES = 5

      partitioned_by :namespace_id, strategy: :int_range, partition_size: PARTITION_SIZE

      enum :state, {
        pending: 0,
        initializing: 1,
        ready: 10,
        orphaned: 230,
        pending_deletion: 240,
        deleted: 250,
        failed: 255
      }

      belongs_to :zoekt_node, inverse_of: :knowledge_graph_replicas, class_name: '::Search::Zoekt::Node'
      belongs_to :knowledge_graph_enabled_namespace, inverse_of: :replicas,
        class_name: 'Ai::KnowledgeGraph::EnabledNamespace'
      has_many :tasks,
        foreign_key: :knowledge_graph_replica_id, inverse_of: :knowledge_graph_replica,
        class_name: '::Ai::KnowledgeGraph::Task'

      before_validation :set_namespace_id

      validates_presence_of :zoekt_node_id, :state, :namespace_id, :schema_version
      validates :knowledge_graph_enabled_namespace_id, uniqueness: { scope: :zoekt_node_id }, allow_nil: true
      validate :namespace_id_matches_enabled_namespace

      private

      def set_namespace_id
        self.namespace_id ||= knowledge_graph_enabled_namespace&.namespace_id
      end

      def namespace_id_matches_enabled_namespace
        return unless namespace_id.present?
        return unless knowledge_graph_enabled_namespace
        return if namespace_id == knowledge_graph_enabled_namespace.namespace_id

        errors.add(:namespace_id, :invalid)
      end
    end
  end
end
