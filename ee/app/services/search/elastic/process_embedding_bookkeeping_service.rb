# frozen_string_literal: true

module Search
  module Elastic
    class ProcessEmbeddingBookkeepingService < ::Elastic::ProcessBookkeepingService
      extend Search::Elastic::Concerns::RateLimiter

      class << self
        def redis_set_key(shard_number)
          "elastic:embedding:updates:#{shard_number}:zset"
        end

        def redis_score_key(shard_number)
          "elastic:embedding:updates:#{shard_number}:score"
        end

        def track_embedding!(item)
          track!(::Search::Elastic::References::Embedding.ref(item))
        end

        def shard_limit
          (threshold / self::SHARDS.count).to_i
        end
      end
    end
  end
end
