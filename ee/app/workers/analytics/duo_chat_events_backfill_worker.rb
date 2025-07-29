# frozen_string_literal: true

module Analytics
  # Backfills usage data to ClickHouse from Postgres when ClickHouse was enabled for analytics
  # Deprecated in favor of Analytics::AiUsageEventsBackfillWorker
  class DuoChatEventsBackfillWorker < BaseUsageBackfillWorker
    include Gitlab::EventStore::Subscriber

    data_consistency :sticky
    feature_category :value_stream_management
    urgency :low
    idempotent!

    def handle_event(*)
      execute_with_rescheduling(*)
    end

    private

    def model_class
      ::Ai::DuoChatEvent
    end
  end
end
