# frozen_string_literal: true

module EE
  module SnippetRepository
    extend ActiveSupport::Concern

    EE_SEARCHABLE_ATTRIBUTES = %i[disk_path].freeze

    prepended do
      include ::Geo::ReplicableModel
      include ::Geo::VerifiableModel
      include ::Geo::VerificationStateDefinition
      include FromUnion
      include ::Gitlab::SQL::Pattern

      with_replicator ::Geo::SnippetRepositoryReplicator

      has_one :snippet_repository_state,
        autosave: false,
        inverse_of: :snippet_repository,
        foreign_key: :snippet_repository_id,
        class_name: '::Geo::SnippetRepositoryState'
    end

    class_methods do
      extend ::Gitlab::Utils::Override

      # Search for a list of snippet_repositories based on the query given in `query`.
      #
      # @param [String] query term that will search over snippet_repositories :disk_path attribute
      #
      # @return [ActiveRecord::Relation<SnippetRepository>] a collection of snippet repositories
      def search(query)
        return all if query.empty?

        fuzzy_search(query, EE_SEARCHABLE_ATTRIBUTES)
      end

      # @return [ActiveRecord::Relation<SnippetRepository>] scope observing selective sync
      #          settings of the given node
      override :selective_sync_scope
      def selective_sync_scope(node, **_params)
        return all unless node.selective_sync?
        return snippet_repositories_for_selected_namespaces(node) if node.selective_sync_by_namespaces?
        return snippet_repositories_for_selected_shards(node) if node.selective_sync_by_shards?

        none
      end

      def snippet_repositories_for_selected_namespaces(node)
        personal_snippets = self.joins(:snippet).where(snippet: ::Snippet.only_personal_snippets)

        project_snippets = self.joins(snippet: :project)
                               .merge(::Snippet.for_projects(::Project.selective_sync_scope(node).select(:id)))

        self.from_union([project_snippets, personal_snippets])
      end

      def snippet_repositories_for_selected_shards(node)
        self.for_repository_storage(node.selective_sync_shards)
      end
    end
  end
end
