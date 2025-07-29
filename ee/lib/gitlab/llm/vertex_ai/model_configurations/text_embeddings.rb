# frozen_string_literal: true

module Gitlab
  module Llm
    module VertexAi
      module ModelConfigurations
        class TextEmbeddings < Base
          extend ::Gitlab::Utils::Override

          NAME = 'text-embedding-005'

          def payload(content)
            {
              instances: content.map { |instance| { content: instance } }
            }
          end

          private

          override :model
          def model
            return options[:model] if options[:model]

            super
          end
        end
      end
    end
  end
end
