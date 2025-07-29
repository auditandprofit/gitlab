# frozen_string_literal: true

module Types
  module WorkItems
    class TextFieldValueType < Types::BaseObject # rubocop:disable Graphql/AuthorizeTypes -- already authorized in parent entity
      graphql_name 'WorkItemTextFieldValue'

      implements Types::WorkItems::CustomFieldValueInterface

      field :value, GraphQL::Types::String, null: true, description: 'Text value of the custom field.'
    end
  end
end
