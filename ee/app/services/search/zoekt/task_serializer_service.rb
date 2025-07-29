# frozen_string_literal: true

module Search
  module Zoekt
    class TaskSerializerService
      KNOWLEDGE_GRAPH_INDEXING_TIMEOUT_S = 1.5.hours.to_i
      attr_reader :task, :node

      def self.execute(...)
        new(...).execute
      end

      def initialize(task, node)
        @task = task
        @node = node
      end

      def execute
        case task.task_type.to_sym
        when :index_repo
          {
            name: :index,
            payload: index_repo_payload
          }
        when :force_index_repo
          {
            name: :index,
            payload: force_index_repo_payload
          }
        when :delete_repo
          {
            name: :delete,
            payload: delete_repo_payload
          }
        when :index_graph_repo
          {
            name: :index_graph,
            payload: index_graph_repo_payload
          }
        when :delete_graph_repo
          {
            name: :delete_graph,
            payload: delete_graph_repo_payload
          }
        else
          raise ArgumentError, "Unknown task_type: #{task.task_type.inspect}"
        end
      end

      private

      def index_repo_payload
        project = task.zoekt_repository.project

        gitaly_payload(project).merge(
          Callback: { name: 'index', payload: { task_id: task.id, schema_version: node.schema_version } },
          RepoId: project.id,
          FileSizeLimit: Gitlab::CurrentSettings.elasticsearch_indexed_file_size_limit_kb.kilobytes,
          Parallelism: ::Gitlab::CurrentSettings.zoekt_indexing_parallelism,
          Timeout: "#{::Search::Zoekt::Settings.indexing_timeout.to_i}s",
          FileCountLimit: ::Gitlab::CurrentSettings.zoekt_maximum_files,
          Metadata: {
            project_id: project.id,
            traversal_ids: project.namespace_ancestry,
            visibility_level: project.visibility_level,
            repository_access_level: project.repository_access_level,
            forked: project.forked? ? "t" : "f",
            archived: project.archived? ? "t" : "f"
          }.transform_values(&:to_s)
        )
      end

      def force_index_repo_payload
        index_repo_payload.merge(Force: true)
      end

      def delete_repo_payload
        {
          RepoId: task.project_identifier,
          Callback: { name: 'delete', payload: { task_id: task.id, service_type: :zoekt } }
        }
      end

      def index_graph_repo_payload
        namespace = task.knowledge_graph_replica.knowledge_graph_enabled_namespace&.namespace
        project = namespace&.project

        gitaly_payload(project).merge(
          NamespaceId: namespace&.id,
          RepoId: project&.id,
          Callback: { name: 'index_graph', payload: { task_id: task.id, service_type: :knowledge_graph } },
          Timeout: "#{KNOWLEDGE_GRAPH_INDEXING_TIMEOUT_S}s"
        )
      end

      def delete_graph_repo_payload
        {
          NamespaceId: task.knowledge_graph_replica.namespace_id,
          Callback: { name: 'delete_graph', payload: { task_id: task.id, service_type: :knowledge_graph } }
        }
      end

      def gitaly_payload(project)
        repository_storage = project.repository_storage
        connection_info = Gitlab::GitalyClient.connection_data(repository_storage)
        repository_path = "#{project.repository.disk_path}.git"
        address = connection_info['address']

        # This code is needed to support relative unix: connection strings. For example, specs
        if address.match?(%r{\Aunix:[^/.]})
          path = address.split('unix:').last
          address = "unix:#{Rails.root.join(path)}"
        end

        {
          GitalyConnectionInfo: {
            Address: address,
            Token: connection_info['token'],
            Storage: repository_storage,
            Path: repository_path
          }
        }
      end
    end
  end
end
