# frozen_string_literal: true

module Search
  class ElasticIndexEmbeddingBulkCronWorker # rubocop:disable Scalability/IdempotentWorker -- worker has deduplication
    include ::Elastic::BulkCronWorker
    include Search::Elastic::Concerns::RateLimiter

    urgency :low
    data_consistency :sticky

    def perform(shard_number = nil)
      return if embeddings_throttled?

      super
    end

    private

    def service
      Search::Elastic::ProcessEmbeddingBookkeepingService.new
    end
  end
end
