# frozen_string_literal: true

module Analytics
  module AiAnalytics
    class DuoUsageService
      include CommonUsageService

      # TODO - Replace with namespace_traversal_path filter
      # after https://gitlab.com/gitlab-org/gitlab/-/issues/531491.
      # Can be removed with use_ai_events_namespace_path_filter feature flag.
      QUERY = <<~SQL
        -- cte to load contributors
        WITH contributors AS (
          SELECT DISTINCT author_id
          FROM "contributions"
          WHERE startsWith(path, {traversal_path:String})
          AND "contributions"."created_at" >= {from:Date}
          AND "contributions"."created_at" <= {to:Date}
        )
        SELECT %{fields}
      SQL

      # Can be removed with use_ai_events_namespace_path_filter feature flag.
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
            GROUP BY id
          ) contributions_new
          WHERE deleted = false
        )
        SELECT %{fields}
      SQL

      DUO_USED_COUNT_QUERY = <<~SQL
        SELECT COUNT(user_id) FROM (
          SELECT DISTINCT user_id
          FROM duo_chat_events_daily
          WHERE user_id IN (SELECT author_id FROM contributors)
          AND date >= {from:Date}
          AND date <= {to:Date}
          AND event = 1
          UNION DISTINCT
          SELECT DISTINCT user_id
          FROM code_suggestion_events_daily
          WHERE user_id IN (SELECT author_id FROM contributors)
          AND date >= {from:Date}
          AND date <= {to:Date}
          AND event IN (1,2,3,5)
        )
      SQL
      private_constant :DUO_USED_COUNT_QUERY

      FIELDS_SUBQUERIES = {
        duo_used_count: DUO_USED_COUNT_QUERY
      }.freeze

      FIELDS = FIELDS_SUBQUERIES.keys
    end
  end
end
