# frozen_string_literal: true

module Gitlab
  module Llm
    module VertexAi
      module Embeddings
        class Text
          BULK_LIMIT = 250

          TOKEN_LIMIT_EXCEEDED = /the input token count is \d+ but the model supports up to \d+/

          TokenLimitExceededError = Class.new(StandardError)

          def initialize(text, user:, tracking_context:, unit_primitive:, model: nil)
            @text = text
            @user = user
            @tracking_context = tracking_context
            @unit_primitive = unit_primitive
            @model = model
          end

          def execute
            content = Array.wrap(text)

            if content.count > BULK_LIMIT
              raise StandardError, "Cannot generate embeddings for more than #{BULK_LIMIT} texts at once"
            end

            result = client.text_embeddings(content: content, model: model)
            response_modifier = ::Gitlab::Llm::VertexAi::ResponseModifiers::Embeddings.new(result)

            handle_errors(result, response_modifier)

            response_modifier.response_body
          end

          private

          attr_reader :user, :text, :tracking_context, :unit_primitive, :model

          def handle_errors(result, response_modifier)
            return if result.success? && response_modifier.response_body.present?

            errors = response_modifier.errors

            raise TokenLimitExceededError, errors if result.bad_request? && token_limit_exceeded?(errors)

            error = errors.any? ? errors : "Could not generate embedding: '#{result}'"
            raise StandardError, error
          end

          def token_limit_exceeded?(errors)
            errors.any? do |e|
              e.match?(TOKEN_LIMIT_EXCEEDED)
            end
          end

          def client
            ::Gitlab::Llm::VertexAi::Client.new(user,
              unit_primitive: unit_primitive,
              tracking_context: tracking_context)
          end
        end
      end
    end
  end
end
