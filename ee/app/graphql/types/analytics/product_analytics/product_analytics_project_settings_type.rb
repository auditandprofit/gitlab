# frozen_string_literal: true

# rubocop: disable Graphql/AuthorizeTypes -- always authorized by Resolver

module Types
  module Analytics
    module ProductAnalytics
      class ProductAnalyticsProjectSettingsType < BaseObject
        graphql_name 'ProductAnalyticsProjectSettings'
        description 'Project-level settings for product analytics provider.'

        field :product_analytics_configurator_connection_string, GraphQL::Types::String, null: true,
          description: 'Connection string for the product analytics configurator.'

        field :cube_api_base_url, GraphQL::Types::String, null: true,
          description: 'Base URL for the Cube API.'

        # rubocop:disable GraphQL/ExtractType -- keep property names matching everywhere else in the codebase
        field :product_analytics_data_collector_host, GraphQL::Types::String, null: true,
          description: 'Host for the product analytics data collector.'

        field :cube_api_key, GraphQL::Types::String, null: true,
          description: 'API key for the Cube API.'
        # rubocop:enable GraphQL/ExtractType
      end
    end
  end
end
# rubocop: enable Graphql/AuthorizeTypes
