# frozen_string_literal: true

module Search
  module Elastic
    class MilestoneQueryBuilder < QueryBuilder
      extend ::Gitlab::Utils::Override

      DOC_TYPE = 'milestone'
      FIELDS = %w[title^2 description].freeze

      def build
        options[:fields] = options[:fields].presence || FIELDS

        query_hash = ::Search::Elastic::Queries.by_full_text(query: query, options: options)
        query_hash = ::Search::Elastic::Filters.by_type(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_project_authorization(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_archived(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Formats.source_fields(query_hash: query_hash, options: options)
        ::Search::Elastic::Formats.size(query_hash: query_hash, options: options)
      end

      private

      override :extra_options
      def extra_options
        {
          doc_type: DOC_TYPE,
          features: [:issues, :merge_requests],
          authorization_use_traversal_ids: false
        }
      end
    end
  end
end
