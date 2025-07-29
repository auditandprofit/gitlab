# frozen_string_literal: true

module Analytics
  module AiAnalytics
    class DuoChatUsageService
      include CommonUsageService

      # TODO - Replace with namespace_traversal_path filter
      # after https://gitlab.com/gitlab-org/gitlab/-/issues/531491
      QUERY = <<~SQL
        -- cte to load code contributors
        WITH contributors AS (
          SELECT DISTINCT author_id
          FROM "contributions"
          WHERE startsWith(path, {traversal_path:String})
          AND "contributions"."created_at" >= {from:Date}
          AND "contributions"."created_at" <= {to:Date}
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
            GROUP BY id
          ) contributions_new
          WHERE deleted = false
        )
        SELECT %{fields}
      SQL

      CONTRIBUTORS_COUNT_QUERY = "SELECT count(*) FROM contributors"
      private_constant :CONTRIBUTORS_COUNT_QUERY

      DUO_CHAT_CONTRIBUTORS_COUNT_QUERY = <<~SQL
        SELECT COUNT(DISTINCT user_id)
          FROM duo_chat_events_daily
          WHERE user_id IN (SELECT author_id FROM contributors)
          AND date >= {from:Date}
          AND date <= {to:Date}
          AND event = 1
      SQL
      private_constant :DUO_CHAT_CONTRIBUTORS_COUNT_QUERY

      FIELDS_SUBQUERIES = {
        contributors_count: CONTRIBUTORS_COUNT_QUERY,
        duo_chat_contributors_count: DUO_CHAT_CONTRIBUTORS_COUNT_QUERY
      }.freeze

      FIELDS = FIELDS_SUBQUERIES.keys
    end
  end
end
