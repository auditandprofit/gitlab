# frozen_string_literal: true

module Search
  module Elastic
    class Relation
      def initialize(klass, query, options)
        @klass = klass
        @query = query
        @options = options
        @preload_values = []
      end

      def before(...)
        paginator.before(...)

        self
      end

      def after(...)
        paginator.after(...)

        self
      end

      def first(limit)
        paginator.first(limit)

        records
      end

      def last(limit)
        paginator.last(limit)

        records.reverse
      end

      def cursor_for(record)
        hit = hit_for(record)

        hit['sort']
      end

      def preload(*preloads)
        @preload_values += preloads

        self
      end

      def to_a
        records
      end

      private

      attr_reader :klass, :query, :options, :preload_values

      delegate :records, to: :response_mapper, private: true
      delegate :query_hash, to: :paginator, private: true

      def response_mapper
        @response_mapper ||= ::Gitlab::Search::Client.execute_search(query: query_hash, options: options) do |response|
          ::Search::Elastic::ResponseMapper.new(response, response_mapper_options)
        end
      end

      def response_mapper_options
        { klass: klass, preloads: preload_values, primary_key: primary_key }
      end

      def paginator
        @paginator ||= Pagination.new(query, primary_key)
      end

      def primary_key
        @primary_key ||= options[:primary_key] || :id
      end

      def hit_for(record)
        @response_mapper.results.find { |result| result['_id'].to_i == record.id }
      end
    end
  end
end
