# frozen_string_literal: true

# This class is used to put all writes to a buffer to avoid individual frequent writes
# and offload main DB.
# It's used mainly for frequent events like code suggestions telemetry.
module Analytics
  class DatabaseWriteBuffer
    include Gitlab::Redis::BackwardsCompatibility

    BUFFER_KEY_POSTFIX = "_db_write_buffer"

    def initialize(buffer_key:)
      @buffer_key = buffer_key
    end

    def add(attributes)
      Gitlab::Redis::SharedState.with do |redis|
        redis.rpush(buffer_key, attributes.to_json)
      end
    end

    def pop(limit)
      Array.wrap(lpop_with_limit(buffer_key, limit)).map { |hash| Gitlab::Json.parse(hash) }
    end

    private

    def buffer_key
      @buffer_key + BUFFER_KEY_POSTFIX
    end
  end
end
