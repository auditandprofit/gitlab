# frozen_string_literal: true

module Ai
  module ActiveContext
    module Embeddings
      module Code
        class VertexText
          EMBEDDINGS_MODEL_CLASS = Gitlab::Llm::VertexAi::Embeddings::Text

          # Vertex bulk limit is 250 so we choose a lower batch size
          # Gitlab::Llm::VertexAi::Embeddings::Text::BULK_LIMIT
          DEFAULT_BATCH_SIZE = 100

          DEFAULT_UNIT_PRIMITIVE = 'generate_embeddings_codebase'

          def self.generate_embeddings(contents, unit_primitive: nil, model: nil, user: nil, batch_size: nil)
            # The caller might explicitly send in `nil` values for these parameters
            # so we need to override here instead of the method signature
            batch_size ||= DEFAULT_BATCH_SIZE
            unit_primitive ||= DEFAULT_UNIT_PRIMITIVE

            new(
              contents,
              unit_primitive: unit_primitive,
              model: model,
              user: user,
              batch_size: batch_size
            ).generate
          end

          def initialize(contents, unit_primitive:, model:, user:, batch_size:)
            @contents = contents
            @unit_primitive = unit_primitive
            @model = model
            @user = user
            @batch_size = batch_size
            @tracking_context = { action: 'embedding' }
          end

          def generate
            embeddings = []
            contents.each_slice(batch_size) do |batch_contents|
              embeddings += generate_with_recursive_batch_splitting(batch_contents)
            end

            embeddings
          end

          private

          attr_reader :contents, :unit_primitive, :model, :user, :batch_size, :tracking_context

          # The caller of the `generate_embeddings` method should already have estimated
          # calculations of the size of `contents` so as not to exceed limits.
          # However, we cannot be certain that those calculations are accurate,
          # so we still need to handle the possibility of a "token limits exceeded" error here.
          #
          # This handles the `TokenLimitExceededError` coming from the embeddings generation call.
          # If the `TokenLimitExceededError` occurs, the `contents` array is split into 2
          # and the embeddings generation is called for each half batch.
          # This has to be done recursively because the new half batch might still exceed limits.
          def generate_with_recursive_batch_splitting(batch_contents)
            embeddings = EMBEDDINGS_MODEL_CLASS.new(
              batch_contents,
              user: user,
              tracking_context: tracking_context,
              unit_primitive: unit_primitive,
              model: model
            ).execute

            embeddings.all?(Array) ? embeddings : [embeddings]

          rescue EMBEDDINGS_MODEL_CLASS::TokenLimitExceededError => e
            batch_contents_count = batch_contents.length
            if batch_contents_count == 1
              # if we are still getting a `TokenLimitExceededError` even with a single content input, raise an error
              raise StandardError, "Token limit exceeded for single content input: #{e.message.inspect}"
            end

            # split the contents input into 2 arrays and recursively call
            # `generate_with_recursive_batch_splitting`
            half_batch_size = (batch_contents_count / 2.0).ceil

            embeddings = []
            batch_contents.each_slice(half_batch_size) do |splitted_batch_contents|
              embeddings += generate_with_recursive_batch_splitting(splitted_batch_contents)
            end

            embeddings
          end
        end
      end
    end
  end
end
