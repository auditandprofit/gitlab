# frozen_string_literal: true

module Types
  module WorkItems
    class NumberFieldValueType < Types::BaseObject # rubocop:disable Graphql/AuthorizeTypes -- already authorized in parent entity
      graphql_name 'WorkItemNumberFieldValue'

      implements Types::WorkItems::CustomFieldValueInterface

      field :value, GraphQL::Types::Float, null: true, description: 'Number value of the custom field.'
    end
  end
end
