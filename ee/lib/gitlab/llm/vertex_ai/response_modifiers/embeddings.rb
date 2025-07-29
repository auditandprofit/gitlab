# frozen_string_literal: true

module Gitlab
  module Llm
    module VertexAi
      module ResponseModifiers
        class Embeddings < ::Gitlab::Llm::BaseResponseModifier
          def response_body
            @response_body ||= if predictions&.any?
                                 results = predictions.map { |res| res['embeddings']['values'] }
                                 results.size == 1 ? results.first : results
                               end
          end

          def errors
            @errors ||= begin
              error_response = ai_response&.dig(:error)

              case error_response
              when nil
                []
              when String
                [error_response]
              else
                [error_response[:message]].compact
              end
            end
          end

          private

          def predictions
            ai_response&.dig('predictions')
          end
        end
      end
    end
  end
end
