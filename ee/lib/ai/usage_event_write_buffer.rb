# frozen_string_literal: true

module Ai
  module UsageEventWriteBuffer
    extend Gitlab::Redis::BackwardsCompatibility

    BUFFER_KEY_PREFIX = 'usage_event_write_buffer_'

    class << self
      def add(model_name, attributes)
        Gitlab::Redis::SharedState.with do |redis|
          redis.rpush(buffer_key(model_name), attributes.to_json)
        end
      end

      def pop(model_name, limit)
        Array.wrap(lpop_with_limit(buffer_key(model_name), limit)).map do |hash|
          Gitlab::Json.parse(hash)
        end
      end

      private

      def buffer_key(model_name)
        "#{BUFFER_KEY_PREFIX}#{model_name.underscore}"
      end
    end
  end
end
