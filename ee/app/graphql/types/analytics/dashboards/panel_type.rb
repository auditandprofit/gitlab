# frozen_string_literal: true

module Types
  module Analytics
    module Dashboards
      class PanelType < BaseObject
        graphql_name 'CustomizableDashboardPanel'
        description 'Represents a customizable dashboard panel.'
        authorize :read_customizable_dashboards

        field :title,
          type: GraphQL::Types::String,
          null: true,
          description: 'Title of the panel.'

        field :grid_attributes,
          type: GraphQL::Types::JSON,
          null: true,
          description: 'Description of the position and size of the panel.'

        field :query_overrides,
          type: GraphQL::Types::JSON,
          null: true,
          description: 'Overrides for the visualization query object.'

        field :visualization,
          type: Types::Analytics::Dashboards::VisualizationType,
          null: true,
          description: 'Visualization of the panel.',
          resolver: Resolvers::Analytics::Dashboards::VisualizationResolver
      end
    end
  end
end
