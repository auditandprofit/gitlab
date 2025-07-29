# frozen_string_literal: true

module Search
  module Zoekt
    class Query
      include Gitlab::Utils::StrongMemoize

      ADVANCED_SYNTAX_FILTERS = %w[extension filename path].freeze
      EXACT_SYNTAX_FILTERS = %w[c case f file lang sym].freeze
      SUPPORTED_SYNTAX_FILTERS = EXACT_SYNTAX_FILTERS + ADVANCED_SYNTAX_FILTERS

      attr_reader :query, :source

      def initialize(query, source: nil)
        raise ArgumentError, 'query argument can not be nil' unless query

        @source = source&.to_sym
        @query = query
      end

      def formatted_query(search_mode)
        term = case search_mode.to_sym
               when :exact
                 RE2::Regexp.escape(keyword)
               when :regex
                 keyword
               else
                 raise ArgumentError, 'Not a valid search_mode'
               end
        return term if filters.empty?

        if source == :api && Feature.enabled?(:zoekt_syntax_transpile, Feature.current_request)
          filters.each do |filter|
            filter_name = filter[%r{^-?(\w+):}, 1]
            next if ADVANCED_SYNTAX_FILTERS.exclude?(filter_name)

            zoekt_syntax = case filter_name
                           when 'extension' then '\1file:\.\2$'
                           when 'filename' then '\1file:(?:^|/)([^/]*\2[^/]*)$'
                           when 'path' then '\1file:(?:^|/)\2'
                           end
            filter.gsub!(%r{^(-?)#{filter_name}:\s*(.+)}, zoekt_syntax)
          end
        end

        term.present? ? "#{term} #{filters.join(' ')}" : filters.join(' ')
      end

      private

      def keyword
        query.gsub(query_matcher_regex, '').strip
      end

      def filters
        @filters ||= query.scan(query_matcher_regex).flatten
      end

      def query_matcher_regex
        Regexp.union(SUPPORTED_SYNTAX_FILTERS.map { |filter| /-?#{filter}:\S+/ })
      end
      strong_memoize_attr(:query_matcher_regex)
    end
  end
end
