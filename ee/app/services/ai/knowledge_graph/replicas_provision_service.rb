# frozen_string_literal: true

module Ai
  module KnowledgeGraph
    class ReplicasProvisionService < ::BaseService
      def initialize(namespace, replica_count:)
        @namespace = namespace
        @replica_count = replica_count
      end

      def execute
        return ::ServiceResponse.error(message: "namespace not set") unless namespace

        create_enabled_namespace

        nodes = available_nodes
        if nodes.size < replica_count
          return ::ServiceResponse.error(message: "couldn't find enough nodes for #{replica_count} replicas")
        end

        replicas = create_replicas(nodes)
        ::ServiceResponse.success(payload: { replicas: replicas })
      end

      private

      attr_reader :namespace, :replica_count

      def create_enabled_namespace
        return if namespace.knowledge_graph_enabled_namespace

        ::Ai::KnowledgeGraph::EnabledNamespace.create!(namespace: namespace)
      end

      def available_nodes
        ::Search::Zoekt::Node
          .available_for_knowledge_graph_namespace(namespace.knowledge_graph_enabled_namespace)
          .order_by_unclaimed_space_desc.online.load
      end

      def create_replicas(nodes)
        replicas = []
        ::Ai::KnowledgeGraph::EnabledNamespace.transaction do
          replica_count.times do |idx|
            replicas << namespace.knowledge_graph_enabled_namespace.replicas.create!(
              zoekt_node: nodes[idx],
              retries_left: ::Ai::KnowledgeGraph::Replica::RETRIES
            )
          end
        end

        replicas
      end
    end
  end
end
