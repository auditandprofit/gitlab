# frozen_string_literal: true

module Analytics
  module AiAnalytics
    class TroubleshootUsageService
      include CommonUsageService

      QUERY = <<~SQL
        SELECT COUNT(DISTINCT user_id) as root_cause_analysis_users_count
        FROM troubleshoot_job_events
        WHERE timestamp >= {from:Date}
        AND timestamp <= {to:Date}
        AND startsWith(namespace_path, {traversal_path:String})
      SQL

      FIELDS_SUBQUERIES = {
        root_cause_analysis_users_count: QUERY
      }.freeze

      FIELDS = FIELDS_SUBQUERIES.keys

      private

      # Overriden from CommonUsageService to be false.
      # The filter for troubleshoot usage does not use contributions
      # table.
      def fetch_contributions_from_new_table?
        false
      end
    end
  end
end
