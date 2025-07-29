# frozen_string_literal: true

module Search
  module Elastic
    class WorkItemQueryBuilder < QueryBuilder
      extend ::Gitlab::Utils::Override
      include Gitlab::Utils::StrongMemoize
      include Search::Elastic::Concerns::SourceType

      DOC_TYPE = 'work_item'
      # iid field can be added here as lenient option will pardon format errors, like integer out of range.
      FIELDS = %w[iid^50 title^2 description].freeze
      THRESHOLD_FOR_GENERATING_EMBEDDING = 10

      # rubocop:disable Metrics/AbcSize -- For now it seems that build steps are logically cohesive as a single unit
      def build
        options[:fields] = fields
        options[:related_ids] = related_ids
        options[:vectors_supported] = vectors_supported

        query_hash = if hybrid_work_item_search?
                       ::Search::Elastic::Queries.by_knn(query: query, options: options)
                     else
                       build_query_hash(query: query, options: options)
                     end

        query_hash = get_authorization_filter(query_hash: query_hash, options: options)
        query_hash = get_confidentiality_filter(query_hash: query_hash, options: options)

        query_hash = ::Search::Elastic::Filters.by_state(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_not_hidden(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_label_ids(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_archived(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_work_item_type_ids(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_author(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_assignees(query_hash: query_hash, options: options)

        if ::Elastic::DataMigrationService.migration_has_finished?(:backfill_work_item_milestone_data)
          query_hash = ::Search::Elastic::Filters.by_milestone(query_hash: query_hash, options: options)
        end

        if ::Elastic::DataMigrationService.migration_has_finished?(:backfill_milestone_state_work_items_index)
          query_hash = ::Search::Elastic::Filters.by_milestone_state(query_hash: query_hash, options: options)
        end

        if ::Elastic::DataMigrationService.migration_has_finished?(:add_extra_fields_to_work_items)
          query_hash = ::Search::Elastic::Filters.by_label_names(query_hash: query_hash, options: options)
          query_hash = ::Search::Elastic::Filters.by_weight(query_hash: query_hash, options: options)
          query_hash = ::Search::Elastic::Filters.by_health_status(query_hash: query_hash, options: options)
        end

        if hybrid_work_item_search?
          query_hash = ::Search::Elastic::Filters.by_knn(query_hash: query_hash, options: options)
        end

        return ::Search::Elastic::Aggregations.by_label_ids(query_hash: query_hash) if options[:aggregation]

        query_hash = ::Search::Elastic::Formats.source_fields(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Formats.page(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Formats.size(query_hash: query_hash, options: options)

        ::Search::Elastic::Sorts.sort_by(query_hash: query_hash, options: options)
      end
      # rubocop:enable Metrics/AbcSize

      private

      def vectors_supported
        return false unless hybrid_work_item_search?
        return :elasticsearch if helper.vectors_supported?(:elasticsearch)
        return :opensearch if helper.vectors_supported?(:opensearch)

        false
      end

      def fields
        return options[:fields] if options[:fields].presence

        FIELDS
      end

      def related_ids
        return [] unless options[:related_ids].present?
        return [] unless Feature.enabled?(:search_work_item_queries_notes, options[:current_user])

        # related_ids are used to search for related notes on noteable records
        # this is not enabled on GitLab.com for global searches
        return [] if options[:search_level].to_sym == :global && ::Gitlab::Saas.feature_available?(:advanced_search)

        options[:related_ids]
      end

      def get_authorization_filter(query_hash:, options:)
        ::Search::Elastic::Filters.by_search_level_and_membership(query_hash: query_hash, options: options)
      end

      def get_confidentiality_filter(query_hash:, options:)
        ::Search::Elastic::Filters.by_project_confidentiality(query_hash: query_hash, options: options)
      end

      # rubocop: disable Gitlab/FeatureFlagWithoutActor -- global flags
      def hybrid_work_item_search?
        return false if iid_query?
        return false if short_query?
        return false if glql_query?(options[:source])
        return false unless Feature.enabled?(:ai_global_switch, type: :ops)
        return false unless Gitlab::Saas.feature_available?(:ai_vertex_embeddings)

        project = Project.find_by_id(options[:project_ids])
        user = options[:current_user]

        return false unless project && user
        return false unless Feature.enabled?(:search_work_items_hybrid_search, user)

        Feature.enabled?(:elasticsearch_work_item_embedding, project, type: :ops) &&
          user.any_group_with_ai_available?
      end
      strong_memoize_attr :hybrid_work_item_search?
      # rubocop: enable Gitlab/FeatureFlagWithoutActor

      override :extra_options
      def extra_options
        embedding_field = :embedding_1
        model = Search::Elastic::References::Embedding::MODEL_VERSIONS[1]

        {
          authorization_use_traversal_ids: true,
          doc_type: DOC_TYPE,
          embedding_field: embedding_field,
          features: 'issues',
          model: model,
          project_visibility_level_field: :project_visibility_level
        }
      end

      def helper
        @helper ||= Gitlab::Elastic::Helper.default
      end

      def short_query?
        query.size < THRESHOLD_FOR_GENERATING_EMBEDDING
      end

      def iid_query?
        query =~ /#(\d+)\z/
      end

      def build_query_hash(query:, options:)
        if iid_query?
          query =~ /#(\d+)\z/ # To get the match correctly
          ::Search::Elastic::Queries.by_iid(iid: Regexp.last_match(1), doc_type: DOC_TYPE)
        else
          ::Search::Elastic::Queries.by_full_text(query: query, options: options)
        end
      end
    end
  end
end
