# frozen_string_literal: true

# This helper is used to reindex the full index based on schema_version value
# The index should have schema_version in the mapping

module Search
  module Elastic
    module MigrationReindexBasedOnSchemaVersion
      include Search::Elastic::IndexName

      UPDATE_BATCH_SIZE = 100
      QUEUE_THRESHOLD = 50_000
      DOC_TYPES_WITH_NON_ID_PK = [Vulnerability].freeze

      def migrate
        if completed?
          log 'Skipping migration since it is already applied', index_name: index_name

          return
        end

        if queue_full?
          log 'Migration is throttled due to full queue'

          return
        end

        log 'Start reindexing', index_name: index_name, batch_size: query_batch_size

        document_references = process_batch!

        log 'Reindexing batch has been processed', index_name: index_name, documents_count: document_references.size
      rescue StandardError => e
        log_raise 'migrate failed', error_class: e.class, error_message: e.message
      end

      def completed?
        doc_count = remaining_documents_count

        log 'Checking the number of documents left with old schema_version', documents_remaining: doc_count

        doc_count == 0
      end

      private

      def bookkeeping_service
        ::Elastic::ProcessInitialBookkeepingService
      end

      def queue_full?
        bookkeeping_service.queue_size > QUEUE_THRESHOLD
      end

      def remaining_documents_count
        helper.refresh_index(index_name: index_name)
        count = client.count(index: index_name, body: query_with_old_schema_version)['count']
        set_migration_state(documents_remaining: count)
        count
      end

      def query_with_old_schema_version
        {
          query: {
            bool: {
              minimum_should_match: 1,
              should: [
                { range: { schema_version: { lt: self.class::NEW_SCHEMA_VERSION } } },
                { bool: { must_not: { exists: { field: 'schema_version' } } } }
              ],
              filter: { term: { type: self.class::DOCUMENT_TYPE.es_type } }
            }
          }
        }
      end

      def process_batch!
        results = client.search(index: index_name, body: query_with_old_schema_version.merge(size: query_batch_size))
        hits = results.dig('hits', 'hits') || []
        document_references = hits.map! do |hit|
          id = hit.dig('_source', reference_primary_key)
          es_id = hit['_id']

          # es_parent attribute is used for routing but is nil for some records, e.g., projects, users
          es_parent = hit['_routing']

          Search::Elastic::Reference.init(self.class::DOCUMENT_TYPE, id, es_id, es_parent)
        end

        document_references.each_slice(update_batch_size) do |refs|
          bookkeeping_service.track!(*refs)
        end

        document_references
      end

      def query_batch_size
        return batch_size if respond_to?(:batch_size)

        raise NotImplementedError
      end

      def update_batch_size
        self.class.const_defined?(:UPDATE_BATCH_SIZE) ? self.class::UPDATE_BATCH_SIZE : UPDATE_BATCH_SIZE
      end

      def reference_primary_key
        if DOC_TYPES_WITH_NON_ID_PK.include?(self.class::DOCUMENT_TYPE)
          ::Search::Elastic::References.const_get(self.class::DOCUMENT_TYPE.to_s,
            false).model_klass.primary_key
        else
          'id'
        end
      end
    end
  end
end
