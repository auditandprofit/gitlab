# frozen_string_literal: true

module Ai
  module KnowledgeGraph
    class IndexingTaskService
      include Gitlab::Utils::StrongMemoize

      def initialize(namespace_id, task_type)
        @namespace_id = namespace_id
        @task_type = task_type.to_sym
      end

      def execute
        error = before_indexing_checks
        if error.present?
          return ::ServiceResponse.error(message: "skipped indexing for namespace #{namespace_id}", reason: error)
        end

        create_indexing_task
      end

      private

      attr_reader :namespace_id, :task_type

      def before_indexing_checks
        return "namespace not found" unless namespace
        return "knowledge_graph_indexing is not enabled" unless Feature.enabled?(:knowledge_graph_indexing, namespace)
        return "project has empty repo" if namespace.project.empty_repo?

        return "project doesn't have duo features available" unless ::GitlabSubscriptions::AddOnPurchase
          .for_active_add_ons(['duo_core'], resource: namespace).present?

        nil
      end

      def create_indexing_task
        replica, error = find_or_create_replica
        return ::ServiceResponse.error(message: "failed to find or create replica: #{error}") unless replica
        return ::ServiceResponse.error(message: "skipping, indexing task exists") if task_exists?

        task = replica.tasks.create!(task_type: task_type, node: replica.zoekt_node)

        ::ServiceResponse.success(payload: { task: task })
      end

      def find_or_create_replica
        replica = namespace.knowledge_graph_enabled_namespace&.replicas&.first
        return [replica, nil] if replica

        result = ReplicasProvisionService.new(namespace, replica_count: 1).execute
        return [nil, result.message] if result.error?

        namespace.knowledge_graph_enabled_namespace.reset
        [result[:replicas].first, nil]
      end

      def task_exists?
        ::Ai::KnowledgeGraph::Task.for_namespace(namespace.knowledge_graph_enabled_namespace)
          .pending.index_graph_repo.exists?
      end

      def namespace
        ::Namespaces::ProjectNamespace.find_by_id(namespace_id)
      end
      strong_memoize_attr :namespace
    end
  end
end
