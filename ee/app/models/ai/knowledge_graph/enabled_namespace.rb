# frozen_string_literal: true

module Ai
  module KnowledgeGraph
    class EnabledNamespace < ApplicationRecord
      include PartitionedTable

      PARTITION_SIZE = 2_000_000

      self.table_name = 'p_knowledge_graph_enabled_namespaces'

      partitioned_by :namespace_id, strategy: :int_range, partition_size: PARTITION_SIZE

      has_many :replicas, foreign_key: :knowledge_graph_enabled_namespace_id,
        inverse_of: :knowledge_graph_enabled_namespace, class_name: 'Ai::KnowledgeGraph::Replica'
      belongs_to :namespace, inverse_of: :knowledge_graph_enabled_namespace, class_name: 'Namespace'

      validates_presence_of :state
      validate :ensure_project_namespace

      enum :state, {
        pending: 0
      }

      private

      def ensure_project_namespace
        return if namespace.is_a?(Namespaces::ProjectNamespace)

        errors.add(:namespace_id, "is not a valid project namespace")
      end
    end
  end
end
