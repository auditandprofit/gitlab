# frozen_string_literal: true

module Analytics
  # Base backfill worker for all Ai::UsageEvent models
  # deprecated in favor of Analytics::UsageEventsBackfillWorker
  # rubocop:disable Scalability/IdempotentWorker -- this is abstract worker.
  class BaseUsageBackfillWorker < ClickHouse::SyncStrategies::BaseSyncStrategy
    RESCHEDULING_DELAY = 1.minute

    def execute_with_rescheduling(event)
      execute.tap do |result|
        log_extra_metadata_on_done(:result, result)

        if !result[:reached_end_of_table] && result[:status] != :disabled
          self.class.perform_in(RESCHEDULING_DELAY, event.class.name, event.data.deep_stringify_keys.to_h)
        end
      end
    end

    private

    def projections
      @projections ||= [
        :id,
        "EXTRACT(epoch FROM timestamp) AS casted_timestamp",
        :user_id,
        "event as raw_event",
        :namespace_path,
        :payload
      ]
    end

    def csv_mapping
      @csv_mapping ||= {
        user_id: :user_id,
        timestamp: :casted_timestamp,
        event: :raw_event,
        namespace_path: :namespace_path
      }
    end

    def transform_row(row)
      row.attributes.merge(row['payload'] || {}).symbolize_keys.slice(*csv_mapping.values)
    end

    def enabled?
      super && ApplicationSetting.current_without_cache.use_clickhouse_for_analytics?
    end

    def insert_query
      <<~SQL.squish
          INSERT INTO #{model_class.clickhouse_table_name} (#{csv_mapping.keys.join(', ')})
          SETTINGS async_insert=1, wait_for_async_insert=1 FORMAT CSV
      SQL
    end
  end
  # rubocop:enable Scalability/IdempotentWorker
end
