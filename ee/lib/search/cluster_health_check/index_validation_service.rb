# frozen_string_literal: true

module Search
  module ClusterHealthCheck
    class IndexValidationService
      include Gitlab::Loggable
      include Gitlab::Utils::StrongMemoize

      # use text id to reduce risk of collision with existing records
      VALIDATION_RECORD_ID = "index_validation_record"
      DEFAULT_OPERATIONS = [:index, :search].freeze

      def self.execute(...)
        new(...).execute
      end

      def initialize(operations: DEFAULT_OPERATIONS, target_classes: nil)
        @target_classes = target_classes
        @requested_operations = operations
      end

      def execute
        return false unless elasticsearch_indexing_enabled?
        return false unless search_cluster_reachable?

        failures = {}
        operations.each do |operation|
          failures.merge!(perform_operation(operation.to_sym, "#{operation} failed"))
        end

        failures.empty?
      rescue ::Elasticsearch::Transport::Transport::Error, ::Faraday::TimeoutError, ::Faraday::ConnectionFailed => e
        logger.error(build_structured_payload(message: 'an error occurred while validating search cluster',
          error_message: e.message,
          error_class: e.class.name))
        false
      end

      private

      def elasticsearch_indexing_enabled?
        return true if ::Gitlab::CurrentSettings.elasticsearch_indexing?

        logger.warn(build_structured_payload(message: 'elasticsearch_indexing is disabled'))
        false
      end

      def search_cluster_reachable?
        return true if elastic_helper.ping?

        logger.warn(build_structured_payload(message: 'search cluster is unreachable'))
        false
      end

      def client
        @client ||= ::Gitlab::Search::Client.new
      end

      def elastic_helper
        @elastic_helper ||= Gitlab::Elastic::Helper.default
      end

      def logger
        @logger = ::Gitlab::Elasticsearch::Logger.build
      end

      def perform_operation(operation, failure_message)
        result = validate(operation)
        failures = result.reject { |_, success| success }
        failures.each_key do |index_alias|
          logger.error(build_structured_payload(message: failure_message, index_alias: index_alias))
        end
        failures
      end

      def validate(operation)
        aliases.each_with_object({}) do |alias_name, result_hash|
          unless elastic_helper.alias_exists?(name: alias_name)
            logger.warn(build_structured_payload(message: 'alias does not exist', alias_name: alias_name))
            next
          end

          index_name = elastic_helper.target_index_name(target: alias_name)
          result_hash[alias_name] = case operation
                                    when :index
                                      index(index_name)
                                    when :search
                                      search(index_name)
                                    end
        end
      end

      def index(index_name)
        result = client.index(
          index: index_name,
          refresh: true,
          id: VALIDATION_RECORD_ID,
          body: {}
        )

        result.dig('_shards', 'failed') == 0
      end

      def search(index_name)
        result = client.search(
          index: index_name,
          size: 0,
          body: {
            query: {
              term: { _id: VALIDATION_RECORD_ID }
            }
          }
        )

        result.dig('hits', 'total', 'value') == 1
      end

      def aliases
        standalone_indices = elastic_helper.standalone_indices_proxies(target_classes: target_klasses)
        aliases = standalone_indices.map(&:index_name)
        aliases << elastic_helper.target_name if target_klasses&.include?(Repository)
        aliases
      end
      strong_memoize_attr :aliases

      def target_klasses
        allowed_classes = ::Gitlab::Elastic::Helper::INDEXED_CLASSES
        (@target_classes.presence || allowed_classes) & allowed_classes
      end
      strong_memoize_attr :target_klasses

      def operations
        (@requested_operations.presence || DEFAULT_OPERATIONS) & DEFAULT_OPERATIONS
      end
      strong_memoize_attr :operations
    end
  end
end
