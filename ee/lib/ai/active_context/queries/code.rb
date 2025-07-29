# frozen_string_literal: true

module Ai
  module ActiveContext
    module Queries
      class Code
        KNN_COUNT = 10
        SEARCH_RESULTS_LIMIT = 10
        COLLECTION_CLASS = ::Ai::ActiveContext::Collections::Code

        NoCollectionRecordError = Class.new(StandardError)

        def initialize(search_term:, user:)
          @search_term = search_term
          @user = user
        end

        def filter(project_id:, path: nil)
          if no_collection_record?
            raise(
              NoCollectionRecordError,
              "A Code collection record is required."
            )
          end

          query = path.nil? ? repository_query(project_id) : directory_query(project_id, path)

          COLLECTION_CLASS.search(query: query, user: user)
        end

        private

        attr_reader :search_term, :user

        def repository_query(project_id)
          ::ActiveContext::Query.filter(
            project_id: project_id
          ).knn(
            target: current_embeddings_field,
            vector: target_embeddings,
            k: KNN_COUNT
          ).limit(
            SEARCH_RESULTS_LIMIT
          )
        end

        def directory_query(project_id, path)
          ::ActiveContext::Query.and(
            ::ActiveContext::Query.filter(project_id: project_id),
            ::ActiveContext::Query.prefix(path: path_with_trailing_slash(path))
          ).knn(
            target: current_embeddings_field,
            vector: target_embeddings,
            k: KNN_COUNT
          ).limit(
            SEARCH_RESULTS_LIMIT
          )
        end

        def path_with_trailing_slash(path)
          path.ends_with?("/") ? path : "#{path}/"
        end

        def no_collection_record?
          COLLECTION_CLASS.collection_record.nil?
        end

        def target_embeddings
          @target_embeddings ||= generate_target_embeddings
        end

        def generate_target_embeddings
          ::ActiveContext::Embeddings.generate_embeddings(
            search_term,
            unit_primitive: embeddings_unit_primitive,
            version: current_embeddings_version
          ).first
        end

        def embeddings_unit_primitive
          ::Ai::ActiveContext::References::Code::UNIT_PRIMITIVE
        end

        def current_embeddings_version
          @current_embeddings_version ||= COLLECTION_CLASS.current_search_embedding_version
        end

        def current_embeddings_field
          current_embeddings_version[:field]
        end
      end
    end
  end
end
