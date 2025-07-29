# frozen_string_literal: true

module Analytics
  module AiAnalytics
    class LastCodeSuggestionUsageService
      QUERY = <<~SQL
        SELECT
          max(date) AS last_used_at, user_id
        FROM code_suggestion_events_daily
          WHERE user_id IN ({user_ids:Array(UInt64)})
          AND date >= {from:Date}
          AND date <= {to:Date}
        GROUP BY user_id
      SQL
      private_constant :QUERY

      MAX_USER_IDS_SIZE = 10_000
      private_constant :MAX_USER_IDS_SIZE

      def initialize(current_user, user_ids:, from:, to:)
        @current_user = current_user
        @user_ids = user_ids
        @from = from
        @to = to
      end

      # Return payload is a hash of {user_id => last_usage_date}
      def execute
        return feature_unavailable_error unless Gitlab::ClickHouse.globally_enabled_for_analytics?

        ServiceResponse.success(payload: last_usages)
      end

      private

      attr_reader :current_user, :user_ids, :from, :to

      def feature_unavailable_error
        ServiceResponse.error(
          message: s_('AiAnalytics|the ClickHouse data store is not available')
        )
      end

      def last_usages
        data = []

        user_ids.each_slice(MAX_USER_IDS_SIZE).map do |user_ids_slice|
          query = ClickHouse::Client::Query.new(
            raw_query: QUERY,
            placeholders: {
              user_ids: user_ids_slice.to_json,
              from: from.to_date.iso8601,
              to: to.to_date.iso8601
            })

          data += ClickHouse::Client.select(query, :main)
        end

        data.to_h do |row|
          [row['user_id'], DateTime.parse(row['last_used_at'])]
        end
      end
    end
  end
end
