# frozen_string_literal: true

module Types
  module WorkItems
    module WidgetDefinitions
      # rubocop:disable Graphql/AuthorizeTypes -- Authorization too granular, parent type is authorized
      class WeightType < BaseObject
        graphql_name 'WorkItemWidgetDefinitionWeight'
        description 'Represents a weight widget definition'

        implements ::Types::WorkItems::WidgetDefinitionInterface

        field :editable, GraphQL::Types::Boolean,
          null: false,
          description: 'Indicates whether editable weight is available.'

        field :roll_up, GraphQL::Types::Boolean,
          null: false,
          description: 'Indicates whether rolled up weight is available.'

        def editable
          object.widget_options[:editable]
        end

        def roll_up
          object.widget_options[:rollup]
        end
      end
      # rubocop:enable Graphql/AuthorizeTypes
    end
  end
end
