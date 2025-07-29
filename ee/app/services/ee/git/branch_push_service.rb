# frozen_string_literal: true

module EE
  module Git
    module BranchPushService
      extend ::Gitlab::Utils::Override

      override :execute
      def execute
        enqueue_elasticsearch_indexing
        enqueue_zoekt_indexing
        enqueue_knowledge_graph_indexing
        enqueue_update_external_pull_requests
        enqueue_product_analytics_event_metrics
        enqueue_repository_xray
        enqueue_sync_pipeline_execution_policy_metadata

        super
      end

      private

      def enqueue_sync_pipeline_execution_policy_metadata
        return unless project.licensed_feature_available?(:security_orchestration_policies)
        return if ::Security::PipelineExecutionPolicyConfigLink.for_project(project).none?

        ::Security::SyncLinkedPipelineExecutionPolicyConfigsWorker
          .perform_async(project.id, current_user.id, oldrev, newrev, ref)
      end

      def enqueue_product_analytics_event_metrics
        return unless project.product_analytics_enabled?
        return unless default_branch?

        ::ProductAnalytics::PostPushWorker.perform_async(project.id, newrev, current_user.id)
      end

      def enqueue_elasticsearch_indexing
        return unless should_index_commits?

        project.repository.index_commits_and_blobs
      end

      def enqueue_zoekt_indexing
        return false unless ::Gitlab::CurrentSettings.zoekt_indexing_enabled?
        return false unless default_branch?
        return false unless project.use_zoekt?

        project.repository.async_update_zoekt_index
      end

      def enqueue_knowledge_graph_indexing
        return false unless ::Feature.enabled?(:knowledge_graph_indexing, project.project_namespace)
        return false unless default_branch?

        return false unless ::GitlabSubscriptions::AddOnPurchase
          .for_active_add_ons(['duo_core'], resource: project.project_namespace).present?

        ::Ai::KnowledgeGraph::IndexingTaskWorker.perform_async(project.project_namespace.id, :index_graph_repo)
      end

      def enqueue_update_external_pull_requests
        return unless project.mirror?
        return unless params.fetch(:create_pipelines, true)

        UpdateExternalPullRequestsWorker.perform_async(
          project.id,
          current_user.id,
          ref
        )
      end

      def should_index_commits?
        return false unless default_branch?

        project.use_elasticsearch?
      end

      def enqueue_repository_xray
        return if removing_branch?
        return unless default_branch? && project.duo_features_enabled

        ::Ai::RepositoryXray::ScanDependenciesWorker.perform_async(project.id)
      end
    end
  end
end
