# frozen_string_literal: true

module Elastic
  module Latest
    class IssueClassProxy < ApplicationClassProxy
      extend ::Gitlab::Utils::Override

      def elastic_search(query, options: {})
        query_hash = ::Search::Elastic::IssueQueryBuilder.build(query: query, options: options)

        search(query_hash, options)
      end

      # rubocop: disable CodeReuse/ActiveRecord -- no ActiveRecord relation
      override :preload_indexing_data
      def preload_indexing_data(relation)
        relation.includes(
          :author,
          :sync_object,
          :namespace,
          :issue_assignees,
          :labels,
          project: [:project_feature, :namespace]
        )
      end
      # rubocop: enable CodeReuse/ActiveRecord

      def issue_aggregations(query, options)
        builder_options = options.merge(aggregation: true)
        query_hash = ::Search::Elastic::IssueQueryBuilder.build(query: query, options: builder_options)
        results = search(query_hash, options)

        ::Gitlab::Search::AggregationParser.call(results.response.aggregations)
      end
    end
  end
end
