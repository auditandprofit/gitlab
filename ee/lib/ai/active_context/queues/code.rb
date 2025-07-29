# frozen_string_literal: true

module Ai
  module ActiveContext
    module Queues
      class Code
        class << self
          # having a single shard means we have absolute control over the amount of embeddings we generate in one go
          def number_of_shards
            1
          end
        end

        include ::ActiveContext::Concerns::Queue
      end
    end
  end
end
