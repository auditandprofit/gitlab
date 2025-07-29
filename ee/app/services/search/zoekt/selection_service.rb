# frozen_string_literal: true

module Search
  module Zoekt
    class SelectionService
      attr_reader :max_batch_size

      ResourcePool = Struct.new(:enabled_namespaces, :nodes)
      MAX_PROJECTS_PER_NAMESPACE = 40_000

      def self.execute(**kwargs)
        new(**kwargs).execute
      end

      def initialize(max_batch_size: 128)
        @max_batch_size = max_batch_size
      end

      def execute
        namespaces = fetch_enabled_namespace_for_indexing
        nodes = fetch_available_nodes

        ResourcePool.new(namespaces, nodes)
      end

      private

      def fetch_enabled_namespace_for_indexing
        [].tap do |batch|
          ::Search::Zoekt::EnabledNamespace.with_missing_indices.with_rollout_allowed.find_each do |ns|
            next if ::Namespace.by_root_id(ns.root_namespace_id).project_namespaces.count > MAX_PROJECTS_PER_NAMESPACE

            batch << ns
            break if batch.count >= max_batch_size
          end
        end
      end

      def fetch_available_nodes
        ::Search::Zoekt::Node.with_service(:zoekt).online.order_by_unclaimed_space_desc
      end
    end
  end
end
