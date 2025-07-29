# frozen_string_literal: true

module Search
  module Elastic
    module Concerns
      module RateLimiter
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override
        include Gitlab::Utils::StrongMemoize

        ENDPOINT = :vertex_embeddings_api
        THRESHOLD_LIMIT = 0.7

        def embeddings_throttled?
          ::Gitlab::ApplicationRateLimiter.peek(ENDPOINT, scope: nil, threshold: threshold)
        end

        def embeddings_throttled_after_increment?
          ::Gitlab::ApplicationRateLimiter.throttled?(ENDPOINT, scope: nil, threshold: threshold)
        end

        def threshold
          ::Gitlab::ApplicationRateLimiter.rate_limits[ENDPOINT][:threshold] * THRESHOLD_LIMIT
        end
        strong_memoize_attr :threshold
      end
    end
  end
end
