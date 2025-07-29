# frozen_string_literal: true

module Search
  module Elastic
    module Delete
      class BaseService
        include Gitlab::Loggable

        QUERY_TIMEOUT = '10m'

        def self.execute(options)
          new(options).execute
        end

        def initialize(options = {})
          @options = options.with_indifferent_access
        end

        def execute
          remove_documents
        end

        private

        attr_reader :options

        def build_query
          raise NotImplementedError
        end

        def index_name
          raise NotImplementedError
        end

        def remove_documents
          return if build_query.blank?

          response = client.delete_by_query({
            index: index_name,
            conflicts: 'proceed',
            timeout: QUERY_TIMEOUT,
            body: build_query
          })

          log_response(response)
        end

        def log_response(response)
          if response['failure'].present?
            log_error(response)
          else
            log_success(response)
          end
        end

        def log_error(response)
          payload = build_structured_payload(
            **options,
            failure: response['failure'],
            message: 'Failed to delete documents',
            index: index_name
          )
          logger.error(payload)
        end

        def log_success(response)
          payload = build_structured_payload(
            **options,
            deleted: response['deleted'],
            message: 'Successfully deleted documents',
            index: index_name
          )
          logger.info(payload)
        end

        def client
          @client ||= ::Gitlab::Search::Client.new
        end

        def logger
          @logger ||= ::Gitlab::Elasticsearch::Logger.build
        end
      end
    end
  end
end
