# frozen_string_literal: true

module Search
  module Elastic
    module Queries
      # advanced search syntax is built off Elasticsearch simple_query_string syntax
      BASIC_OPERATORS_REGEX = /[*"~#!()|]/
      INCLUDE_EXCLUDE_REGEX = /(?:^|\s)[+\-]/
      ADVANCED_QUERY_SYNTAX_REGEX = /#{BASIC_OPERATORS_REGEX}|#{INCLUDE_EXCLUDE_REGEX}/

      DEFAULT_RELATED_ID_BOOST = 0.7
      UNIT_PRIMITIVE = 'semantic_search_issue'
      KNN_K = 25
      KNN_NUM_CANDIDATES = 100
      DEFAULT_HYBRID_SIMILARITY = 0.6
      DEFAULT_HYBRID_BOOST = 5
      SIMPLE_QUERY_STRING_BOOST = 0.2
      ALLOWED_SEARCH_CLIENTS = %i[elasticsearch opensearch].freeze

      class << self
        include ::Elastic::Latest::QueryContext::Aware
        include Search::Elastic::Concerns::RateLimiter

        def by_iid(iid:, doc_type:)
          bool_expr = ::Search::Elastic::BoolExpr.new
          bool_expr.filter = [
            { term: { iid: { _name: context.name(doc_type, :related, :iid), value: iid } } },
            { term: { type: { _name: context.name(:doc, :is_a, doc_type), value: doc_type } } }
          ]

          {
            query: {
              bool: bool_expr
            }
          }
        end

        def by_full_text(query:, options:)
          if ADVANCED_QUERY_SYNTAX_REGEX.match?(query)
            by_simple_query_string(fields: options[:fields], query: query, options: options)
          else
            by_multi_match_query(fields: options[:fields], query: query, options: options)
          end
        end

        def by_multi_match_query(fields:, query:, options:)
          query_fields = prepare_query_fields(fields, options[:count_only])
          bool_expr = build_multi_match_bool_expression(query, query_fields, options)

          query_hash = { query: { bool: bool_expr } }
          query_hash[:track_scores] = true unless query.present?
          query_hash[:highlight] = apply_highlight(query_fields) unless options[:count_only]

          query_hash
        end

        def by_simple_query_string(fields:, query:, options:)
          query_fields = prepare_query_fields(fields, options[:count_only])
          bool_expr = build_simple_query_string_bool_expression(query, query_fields, options)

          query_hash = { query: { bool: bool_expr } }
          query_hash[:track_scores] = true unless query.present?
          query_hash[:highlight] = apply_highlight(query_fields) unless options[:count_only]

          query_hash
        end

        def by_knn(query:, options:)
          return by_full_text(query: query, options: options) unless options[:vectors_supported]

          embedding = get_embedding_for_hybrid_query(query: query, options: options)
          return by_full_text(query: query, options: options) unless embedding
          raise ArgumentError, 'Invalid search client' if ALLOWED_SEARCH_CLIENTS.exclude?(options[:vectors_supported])

          if options[:vectors_supported] == :opensearch
            build_opensearch_knn_query(query: query, options: options, embedding: embedding)
          else
            build_elasticsearch_knn_query(query: query, options: options, embedding: embedding)
          end
        end

        private

        def prepare_query_fields(fields, count_only)
          query_fields = fields.dup
          query_fields = ::Elastic::Latest::CustomLanguageAnalyzers.add_custom_analyzers_fields(query_fields)
          query_fields = remove_fields_boost(query_fields) if count_only
          query_fields
        end

        def build_simple_query_string_bool_expression(query, query_fields, options)
          bool_expr = ::Search::Elastic::BoolExpr.new

          if query.present?
            add_doc_type_filter(bool_expr, options) unless options[:no_join_project]
            add_query_conditions(bool_expr, simple_query_string(query_fields, query, options), options)
          else
            bool_expr.must = { match_all: {} }
          end

          bool_expr
        end

        def build_multi_match_bool_expression(query, query_fields, options)
          bool_expr = ::Search::Elastic::BoolExpr.new

          if query.present?
            add_doc_type_filter(bool_expr, options) unless options[:no_join_project]
            multi_match_bool = ::Search::Elastic::BoolExpr.new
            multi_match_bool.should << multi_match_query(query_fields, query, options.merge(operator: :and))
            multi_match_bool.should << multi_match_phrase_query(query_fields, query, options)
            multi_match_bool.minimum_should_match = 1
            multi_match_query = { bool: multi_match_bool.to_h }

            add_query_conditions(bool_expr, multi_match_query, options)
          else
            bool_expr.must = { match_all: {} }
          end

          bool_expr
        end

        def add_doc_type_filter(bool_expr, options)
          bool_expr.filter << {
            term: {
              type: {
                _name: context.name(:doc, :is_a, options[:doc_type]),
                value: options[:doc_type]
              }
            }
          }
        end

        def add_query_conditions(bool_expr, query, options)
          if options[:count_only]
            bool_expr.filter << query
          elsif options[:keyword_match_clause] == :should || options[:related_ids].present?
            bool_expr.should << query
            bool_expr.should << related_ids_query(options) if options[:related_ids].present?
            bool_expr.minimum_should_match = 1
          else
            bool_expr.must << query
          end
        end

        def get_embedding_for_hybrid_query(query:, options:)
          return options[:embeddings] if options[:embeddings]

          options[:embeddings] = embedding(query, options)
        rescue StandardError => e
          Gitlab::ErrorTracking.track_exception(e)
          nil
        end

        def build_opensearch_knn_query(query:, options:, embedding:)
          options[:simple_query_string_boost] = SIMPLE_QUERY_STRING_BOOST
          options[:keyword_match_clause] = :should

          knn_query = {
            knn: {
              options[:embedding_field] => {
                k: KNN_K,
                vector: embedding
              }
            }
          }

          query_hash = by_full_text(query: query, options: options)
          query_hash[:query][:bool][:should].append(knn_query)

          query_hash
        end

        def build_elasticsearch_knn_query(query:, options:, embedding:)
          query_hash = by_full_text(query: query, options: options)

          knn_query = {
            knn: {
              field: options[:embedding_field].to_s,
              query_vector: embedding,
              boost: options[:hybrid_boost] || DEFAULT_HYBRID_BOOST,
              k: KNN_K,
              num_candidates: KNN_NUM_CANDIDATES,
              similarity: options[:hybrid_similarity] || DEFAULT_HYBRID_SIMILARITY
            }
          }

          query_hash.merge(knn_query)
        end

        def remove_fields_boost(fields)
          fields.map { |m| m.split('^').first }
        end

        def simple_query_string(fields, query, options)
          query_hash = {
            _name: context.name(options[:doc_type], :match, :search_terms),
            fields: fields,
            query: query,
            lenient: true,
            default_operator: :and
          }

          query_hash[:boost] = options[:simple_query_string_boost] if options[:simple_query_string_boost]

          {
            simple_query_string: query_hash
          }
        end

        def multi_match_phrase_query(fields, query, options)
          {
            multi_match: {
              _name: context.name(options[:doc_type], :multi_match_phrase, :search_terms),
              type: :phrase,
              fields: fields,
              query: query,
              lenient: true
            }
          }
        end

        def multi_match_query(fields, query, options)
          {
            multi_match: {
              _name: context.name(options[:doc_type], :multi_match, options[:operator], :search_terms),
              fields: fields,
              query: query,
              operator: options[:operator],
              lenient: true
            }
          }
        end

        def related_ids_query(options)
          related_ids = options[:related_ids]
          return unless related_ids.present?

          {
            terms: {
              _name: context.name(options[:doc_type], :related, :ids),
              id: related_ids,
              boost: options.fetch(:related_ids_boost, DEFAULT_RELATED_ID_BOOST)
            }
          }
        end

        def apply_highlight(fields)
          es_fields = fields.map { |field| field.split('^').first }.each_with_object({}) do |field, memo|
            memo[field.to_sym] = {}
          end

          # Adding number_of_fragments: 0 to not split results into snippets.
          # This way controllers can decide how to handle the highlighted data.
          {
            fields: es_fields,
            number_of_fragments: 0,
            pre_tags: [::Elastic::Latest::GitClassProxy::HIGHLIGHT_START_TAG],
            post_tags: [::Elastic::Latest::GitClassProxy::HIGHLIGHT_END_TAG]
          }
        end

        def embedding(query, options)
          tracking_context = { action: 'hybrid_issue_search_embedding' }
          user = options[:current_user]
          model = options[:model]

          if embeddings_throttled_after_increment?
            raise StandardError, "Rate limited endpoint '#{ENDPOINT}' is throttled"
          end

          Gitlab::Llm::VertexAi::Embeddings::Text
            .new(query, user: user, tracking_context: tracking_context, unit_primitive: UNIT_PRIMITIVE, model: model)
            .execute
        end
      end
    end
  end
end
