# frozen_string_literal: true

module Analytics
  module AiAnalytics
    class CodeSuggestionUsageService
      include CommonUsageService

      # TODO - Replace with namespace_traversal_path filter
      # after https://gitlab.com/gitlab-org/gitlab/-/issues/531491.
      QUERY = <<~SQL
        -- cte to load code contributors
        WITH contributors AS (
          SELECT DISTINCT author_id
          FROM "contributions"
          WHERE startsWith(path, {traversal_path:String})
          AND "contributions"."created_at" >= {from:Date}
          AND "contributions"."created_at" <= {to:Date}
          AND "contributions"."action" = 5
        )
        SELECT %{fields}
      SQL

      NEW_QUERY = <<~SQL
        -- cte to load contributors
        WITH contributors AS (
          SELECT DISTINCT author_id
          FROM (
            SELECT
              argMax(author_id, "contributions_new".version) AS author_id,
              argMax(deleted, "contributions_new".version) AS deleted
            FROM contributions_new
            WHERE startsWith(path, {traversal_path:String})
            AND "contributions_new"."created_at" >= {from:Date}
            AND "contributions_new"."created_at" <= {to:Date}
            AND "contributions_new"."action" = 5
            GROUP BY id
          ) contributions_new
          WHERE deleted = false
        )
        SELECT %{fields}
      SQL

      CODE_CONTRIBUTORS_COUNT_QUERY = "SELECT count(*) FROM contributors"
      private_constant :CODE_CONTRIBUTORS_COUNT_QUERY

      code_suggestion_usage_events = ::Ai::CodeSuggestionEvent.events.values_at(
        'code_suggestions_requested',
        'code_suggestion_shown_in_ide',
        'code_suggestion_direct_access_token_refresh'
      ).join(', ')

      # Can be removed with deprecated fields from GraphQL aiMetrics endpoint
      # more information at https://gitlab.com/gitlab-org/gitlab/-/issues/536606
      CODE_SUGGESTIONS_CONTRIBUTORS_COUNT_QUERY = <<~SQL.freeze
        SELECT COUNT(DISTINCT user_id)
          FROM code_suggestion_events_daily
          WHERE user_id IN (SELECT author_id FROM contributors)
          AND date >= {from:Date}
          AND date <= {to:Date}
          AND event IN (#{code_suggestion_usage_events})
      SQL
      private_constant :CODE_SUGGESTIONS_CONTRIBUTORS_COUNT_QUERY

      # Can be removed with deprecated fields from GraphQL aiMetrics endpoint
      # more information at https://gitlab.com/gitlab-org/gitlab/-/issues/536606
      CODE_SUGGESTIONS_SHOWN_COUNT_QUERY = <<~SQL.freeze
        SELECT SUM(occurrences)
        FROM code_suggestion_events_daily
        WHERE user_id IN (SELECT author_id FROM contributors)
        AND date >= {from:Date}
        AND date <= {to:Date}
        AND event = #{::Ai::CodeSuggestionEvent.events['code_suggestion_shown_in_ide']}
      SQL
      private_constant :CODE_SUGGESTIONS_SHOWN_COUNT_QUERY

      # Can be removed with deprecated fields from GraphQL aiMetrics endpoint
      # more information at https://gitlab.com/gitlab-org/gitlab/-/issues/536606
      CODE_SUGGESTIONS_ACCEPTED_COUNT_QUERY = <<~SQL.freeze
        SELECT SUM(occurrences)
        FROM code_suggestion_events_daily
        WHERE user_id IN (SELECT author_id FROM contributors)
        AND date >= {from:Date}
        AND date <= {to:Date}
        AND event = #{::Ai::CodeSuggestionEvent.events['code_suggestion_accepted_in_ide']}
      SQL
      private_constant :CODE_SUGGESTIONS_ACCEPTED_COUNT_QUERY

      private_class_method def self.build_query(field_select_sql:, event_types_filter:)
        <<~SQL.freeze
          SELECT #{field_select_sql}
          FROM code_suggestion_events_daily
          WHERE user_id IN (SELECT author_id FROM contributors)
          AND date >= {from:Date}
          AND date <= {to:Date}
          AND event IN (#{event_types_filter})
          AND (
            length({languages:Array(String)}) = 0
            OR language IN {languages:Array(String)}
          )
        SQL
      end

      CONTRIBUTORS_COUNT_QUERY = build_query(
        field_select_sql: 'COUNT(DISTINCT user_id)',
        event_types_filter: code_suggestion_usage_events
      ).freeze
      private_constant :CONTRIBUTORS_COUNT_QUERY

      SHOWN_COUNT_QUERY = build_query(
        field_select_sql: 'SUM(occurrences)',
        event_types_filter: ::Ai::CodeSuggestionEvent.events['code_suggestion_shown_in_ide']
      ).freeze
      private_constant :SHOWN_COUNT_QUERY

      SUGGESTIONS_SHOWN_LOC_QUERY = build_query(
        field_select_sql: 'SUM(suggestions_size_sum)',
        event_types_filter: ::Ai::CodeSuggestionEvent.events['code_suggestion_shown_in_ide']
      ).freeze
      private_constant :SUGGESTIONS_SHOWN_LOC_QUERY

      ACCEPTED_COUNT_QUERY = build_query(
        field_select_sql: 'SUM(occurrences)',
        event_types_filter: ::Ai::CodeSuggestionEvent.events['code_suggestion_accepted_in_ide']
      ).freeze
      private_constant :ACCEPTED_COUNT_QUERY

      SUGGESTIONS_ACCEPTED_LOC_QUERY = build_query(
        field_select_sql: 'SUM(suggestions_size_sum)',
        event_types_filter: ::Ai::CodeSuggestionEvent.events['code_suggestion_accepted_in_ide']
      ).freeze
      private_constant :SUGGESTIONS_ACCEPTED_LOC_QUERY

      LANGUAGES_QUERY = build_query(
        field_select_sql: 'groupArray(DISTINCT language)',
        event_types_filter: [
          ::Ai::CodeSuggestionEvent.events['code_suggestion_accepted_in_ide'],
          ::Ai::CodeSuggestionEvent.events['code_suggestion_shown_in_ide']
        ]
      ).freeze
      private_constant :LANGUAGES_QUERY

      FIELDS_SUBQUERIES = {
        # Legacy queries, can be removed with deprecated fields from GraphQL aiMetrics endpoint
        code_contributors_count: CODE_CONTRIBUTORS_COUNT_QUERY,
        code_suggestions_contributors_count: CODE_SUGGESTIONS_CONTRIBUTORS_COUNT_QUERY,
        code_suggestions_shown_count: CODE_SUGGESTIONS_SHOWN_COUNT_QUERY,
        code_suggestions_accepted_count: CODE_SUGGESTIONS_ACCEPTED_COUNT_QUERY,
        # New queries
        contributors_count: CONTRIBUTORS_COUNT_QUERY,
        shown_count: SHOWN_COUNT_QUERY,
        accepted_count: ACCEPTED_COUNT_QUERY,
        languages: LANGUAGES_QUERY,
        shown_lines_of_code: SUGGESTIONS_SHOWN_LOC_QUERY,
        accepted_lines_of_code: SUGGESTIONS_ACCEPTED_LOC_QUERY
      }.freeze

      FIELDS = FIELDS_SUBQUERIES.keys

      attr_reader :languages

      def initialize(current_user, namespace:, from:, to:, languages: [], fields: nil)
        @languages = languages || []
        super(current_user, namespace:, from:, to:, fields:)
      end

      private

      def placeholders
        # Replace double quotes with single quotes to match ClickHouse IN statement syntax
        languages_param = languages.to_s.tr('"', "'")

        super.merge(languages: languages_param)
      end
    end
  end
end
