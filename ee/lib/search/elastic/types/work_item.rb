# frozen_string_literal: true

module Search
  module Elastic
    module Types
      class WorkItem
        VERTEX_TEXT_EMBEDDING_DIMENSION = 768
        OPENSEARCH_EF_CONSTRUCTION = 100
        OPENSEARCH_M = 16
        LUCENE_MIN_VERSION = '2.1.0'

        class << self
          def index_name
            Search::Elastic::References::WorkItem.index
          end

          def target
            ::WorkItem
          end

          def mappings
            mappings = base_mappings
            mappings = elasticsearch_8_plus_mappings(mappings)
            mappings = opensearch_mappings(mappings)

            {
              dynamic: 'strict',
              properties: mappings
            }
          end

          def settings
            settings = base_settings
            opensearch_settings(settings)
          end

          def elasticsearch_8_plus_mappings(mappings = {})
            return mappings unless helper.vectors_supported?(:elasticsearch)

            mappings.merge({
              embedding_0: elastic_knn_field,
              embedding_1: elastic_knn_field
            })
          end

          def opensearch_mappings(mappings = {})
            return mappings unless helper.vectors_supported?(:opensearch)

            mappings.merge({
              embedding_0: opensearch_knn_field,
              embedding_1: opensearch_knn_field
            })
          end

          def elastic_knn_field
            {
              type: 'dense_vector',
              dims: VERTEX_TEXT_EMBEDDING_DIMENSION,
              similarity: 'cosine',
              index: true
            }
          end

          def opensearch_knn_field
            {
              type: 'knn_vector',
              dimension: VERTEX_TEXT_EMBEDDING_DIMENSION,
              method: {
                name: 'hnsw',
                engine: opensearch_engine,
                space_type: 'cosinesimil',
                parameters: {
                  ef_construction: OPENSEARCH_EF_CONSTRUCTION,
                  m: OPENSEARCH_M
                }
              }
            }
          end

          private

          def opensearch_settings(settings)
            return settings unless helper.vectors_supported?(:opensearch)

            settings.deep_merge({ index: { knn: true } })
          end

          def base_mappings
            {
              type: { type: 'keyword' },
              id: { type: 'integer' },
              iid: { type: 'integer' },
              title: { type: 'text', index_options: 'positions', analyzer: :title_analyzer },
              description: { type: 'text', index_options: 'positions', analyzer: :code_analyzer },
              namespace_id: { type: 'integer' },
              root_namespace_id: { type: 'integer' },
              created_at: { type: 'date' },
              updated_at: { type: 'date' },
              due_date: { type: 'date' },
              state: { type: 'keyword' },
              project_id: { type: 'integer' },
              routing: { type: 'text' },
              author_id: { type: 'integer' },
              confidential: { type: 'boolean' },
              hidden: { type: 'boolean' },
              archived: { type: 'boolean' },
              assignee_id: { type: 'integer' },
              project_visibility_level: { type: 'short' },
              namespace_visibility_level: { type: 'short' },
              issues_access_level: { type: 'short' },
              upvotes: { type: 'integer' },
              traversal_ids: { type: 'keyword' },
              label_ids: { type: 'keyword' },
              hashed_root_namespace_id: { type: 'integer' },
              work_item_type_id: { type: 'integer' },
              schema_version: { type: 'short' },
              milestone_title: { type: 'keyword' },
              milestone_id: { type: 'long' },
              milestone_start_date: { type: 'date' },
              milestone_due_date: { type: 'date' },
              milestone_state: { type: 'keyword' },
              closed_at: { type: 'date' },
              weight: { type: 'integer' },
              health_status: { type: 'short' },
              label_names: { type: 'keyword' }
            }
          end

          def base_settings
            ::Elastic::Latest::Config.settings.to_hash.deep_merge(
              index: ::Elastic::Latest::Config.separate_index_specific_settings(index_name)
            )
          end

          def helper
            @helper ||= Gitlab::Elastic::Helper.default
          end

          def opensearch_engine
            helper = Gitlab::Elastic::Helper.default
            if helper.matching_distribution?(:opensearch, min_version: LUCENE_MIN_VERSION, inclusive: false)
              'lucene'
            else
              'nmslib'
            end
          end
        end
      end
    end
  end
end
