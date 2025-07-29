# frozen_string_literal: true

module Types
  module Ai
    module ModelSelection
      # rubocop: disable Graphql/AuthorizeTypes -- authorization in resolver/mutation
      class OfferedModelType < ::Types::BaseObject
        graphql_name 'AiModelSelectionOfferedModel'
        description 'Model offered for Model Selection'

        field :ref, String, null: false, description: 'Identifier for the offered model.'

        field :name, String, null: false, description: 'Humanized name for the offered model, e.g "Chat GPT 4o".'
      end
      # rubocop: enable Graphql/AuthorizeTypes
    end
  end
end
