# frozen_string_literal: true

module Ai
  module ActiveContext
    module References
      class Code < ::ActiveContext::Reference
        UNIT_PRIMITIVE = 'generate_embeddings_codebase'

        add_preprocessor :get_content do |refs|
          identifiers = refs.map(&:identifier)
          query = ::ActiveContext::Query.filter(id: identifiers).limit(identifiers.count)

          fetch_content(refs: refs, query: query, collection: Collections::Code)
        end

        add_preprocessor :embeddings do |refs|
          apply_embeddings(refs: refs, remove_content: false, unit_primitive: UNIT_PRIMITIVE)
        end

        def self.serialize_data(data)
          { identifier: data[:id] }
        end

        attr_accessor :identifier

        def init
          @identifier = serialized_args.first
        end

        def serialized_attributes
          [identifier]
        end

        def unique_identifier(_)
          identifier
        end

        def operation
          :update
        end

        def as_indexed_json
          {}
        end
      end
    end
  end
end
