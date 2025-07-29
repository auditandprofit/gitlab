# frozen_string_literal: true

module Analytics
  # Backfills usage data to ClickHouse from Postgres when ClickHouse was enabled for analytics
  # Deprecated in favor of Analytics::AiUsageEventsBackfillWorker
  class CodeSuggestionsEventsBackfillWorker < BaseUsageBackfillWorker
    include Gitlab::EventStore::Subscriber

    data_consistency :sticky
    feature_category :value_stream_management
    urgency :low
    idempotent!

    def handle_event(*)
      execute_with_rescheduling(*)
    end

    private

    def csv_mapping
      super.merge(
        suggestion_size: :suggestion_size,
        language: :language,
        branch_name: :branch_name,
        unique_tracking_id: :unique_tracking_id
      )
    end

    def model_class
      ::Ai::CodeSuggestionEvent
    end
  end
end
