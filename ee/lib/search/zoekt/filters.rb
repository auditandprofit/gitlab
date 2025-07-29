# frozen_string_literal: true

module Search
  module Zoekt
    module Filters
      class << self
        def by_substring(pattern:, case_sensitive: nil, file_name: nil, content: nil)
          filter = {
            pattern: pattern,
            case_sensitive: case_sensitive,
            file_name: file_name,
            content: content
          }.compact

          { substring: filter }
        end

        def by_repo_ids(ids)
          raise ArgumentError, "ids must be an Array, got #{ids.class}" unless ids.is_a?(Array)

          { repo_ids: ids.map(&:to_i) }
        end

        def by_regexp(regexp:, case_sensitive: nil, file_name: nil, content: nil)
          filter = {
            regexp: regexp,
            case_sensitive: case_sensitive,
            file_name: file_name,
            content: content
          }.compact

          { regexp: filter }
        end

        def and_filters(*filters)
          { and: { children: filters } }
        end

        def or_filters(*filters)
          { or: { children: filters } }
        end

        def not_filter(filter)
          { not: { child: filter } }
        end

        def by_symbol(expr)
          { symbol: { expr: expr } }
        end

        def by_meta(key:, value:)
          { meta: { key: key.to_s, value: value.to_s } }
        end

        def by_forked(value)
          by_meta(key: 'forked', value: value ? 't' : 'f')
        end

        def by_archived(value)
          by_meta(key: 'archived', value: value ? 't' : 'f')
        end

        def by_query_string(query)
          raise ArgumentError, 'Query string cannot be empty' if query.blank?

          { query_string: { query: query } }
        end
      end
    end
  end
end
