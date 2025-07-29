# frozen_string_literal: true

module Search
  module Zoekt
    class UpdateIndexUsedStorageBytesEventWorker
      include Gitlab::EventStore::Subscriber
      include Search::Zoekt::EventWorker
      prepend ::Geo::SkipSecondary

      idempotent!
      defer_on_database_health_signal :gitlab_main, [:zoekt_indices, :zoekt_repositories], 10.minutes

      BATCH_SIZE = 1000

      def handle_event(_event)
        indices = Index.with_stale_used_storage_bytes_updated_at.ordered_by_used_storage_updated_at
        indices.limit(BATCH_SIZE).each(&:update_storage_bytes_and_watermark_level!)

        reemit_event
      end

      private

      def reemit_event
        return unless Index.with_stale_used_storage_bytes_updated_at.exists?

        Gitlab::EventStore.publish(Search::Zoekt::UpdateIndexUsedStorageBytesEvent.new(data: {}))
      end
    end
  end
end
