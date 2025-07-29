# frozen_string_literal: true

module Search
  module Elastic
    class ProjectQueryBuilder < QueryBuilder
      extend ::Gitlab::Utils::Override

      DOC_TYPE = 'project'
      FIELDS = %w[name^10 name_with_namespace^2 path_with_namespace path^9 description].freeze

      def build
        options[:fields] = options[:fields].presence || FIELDS

        query_hash = ::Search::Elastic::Queries.by_full_text(query: query, options: options)
        query_hash = ::Search::Elastic::Filters.by_type(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_archived(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_search_level_and_membership(query_hash: query_hash, options: options)
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
          project_id_field: :id
        }
      end
    end
  end
end
