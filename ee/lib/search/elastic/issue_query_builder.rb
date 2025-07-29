# frozen_string_literal: true

module Search
  module Elastic
    class IssueQueryBuilder < QueryBuilder
      extend ::Gitlab::Utils::Override

      DOC_TYPE = 'issue'
      FIELDS = %w[iid^3 title^2 description].freeze

      def build
        options[:fields] = options[:fields].presence || FIELDS

        query_hash = build_query_hash(query: query, options: options)
        query_hash = ::Search::Elastic::Filters.by_project_authorization(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_project_confidentiality(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_state(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_not_hidden(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_label_ids(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_archived(query_hash: query_hash, options: options)

        return ::Search::Elastic::Aggregations.by_label_ids(query_hash: query_hash) if options[:aggregation]

        query_hash = ::Search::Elastic::Formats.source_fields(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Formats.page(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Formats.size(query_hash: query_hash, options: options)

        ::Search::Elastic::Sorts.sort_by(query_hash: query_hash, options: options)
      end

      private

      override :extra_options
      def extra_options
        {
          doc_type: DOC_TYPE,
          features: 'issues',
          traversal_ids_prefix: :namespace_ancestry_ids,
          authorization_use_traversal_ids: true
        }
      end

      def build_query_hash(query:, options:)
        if query =~ /#(\d+)\z/
          ::Search::Elastic::Queries.by_iid(iid: Regexp.last_match(1), doc_type: DOC_TYPE)
        else
          ::Search::Elastic::Queries.by_full_text(query: query, options: options)
        end
      end
    end
  end
end
