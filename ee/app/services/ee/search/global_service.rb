# frozen_string_literal: true

module EE
  module Search
    module GlobalService
      extend ::Gitlab::Utils::Override
      include ::Gitlab::Utils::StrongMemoize
      include ::Search::AdvancedAndZoektSearchable

      def elasticsearch_results
        ::Gitlab::Elastic::SearchResults.new(
          current_user,
          params[:search],
          elastic_projects,
          public_and_internal_projects: elastic_global,
          order_by: params[:order_by],
          sort: params[:sort],
          filters: filters,
          source: params[:source]
        )
      end

      override :zoekt_searchable_scope?
      def zoekt_searchable_scope?
        ::Feature.enabled?(:zoekt_cross_namespace_search, current_user)
      end

      override :search_level
      def search_level
        :global
      end

      override :root_ancestor
      def root_ancestor; end

      override :zoekt_node_id
      def zoekt_node_id; end

      # This method isn't compatible with multi-node search, so we override it
      # to always return true.
      override :zoekt_node_available_for_search?
      def zoekt_node_available_for_search?
        true
      end

      def elasticsearchable_scope
        nil
      end

      def elastic_global
        true
      end

      def elastic_projects
        # For elasticsearch we need the list of projects to be as small as
        # possible since they are loaded from the DB and sent in the
        # Elasticsearch query. It should only be strictly the project IDs the
        # user has been given authorization for. The Elasticsearch query will
        # additionally take care of public projects. This behaves differently
        # to the searching Postgres case in which this list of projects is
        # intended to be all projects that should appear in the results.
        if current_user&.can_read_all_resources?
          :any
        elsif current_user
          current_user.authorized_projects.pluck_primary_key
        else
          []
        end
      end
      strong_memoize_attr :elastic_projects

      def zoekt_project_id; end

      def zoekt_group_id; end

      override :allowed_scopes
      def allowed_scopes
        scopes = super

        scopes += %w[blobs commits epics notes wiki_blobs] if use_elasticsearch?
        scopes += %w[blobs] if use_zoekt?

        scopes.uniq
      end
      strong_memoize_attr :allowed_scopes
    end
  end
end
