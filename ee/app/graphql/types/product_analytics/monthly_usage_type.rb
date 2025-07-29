# frozen_string_literal: true

module Types
  module ProductAnalytics
    class MonthlyUsageType < BaseObject # rubocop:disable Graphql/AuthorizeTypes -- Authorization is done in resolver layer
      graphql_name 'MonthlyUsage'
      description 'Product analytics events for a specific month and year.'

      field :count, GraphQL::Types::Int, null: true, description: 'Count of product analytics events.'
      field :month, GraphQL::Types::Int, null: false, description: 'Month of the data.'
      field :year, GraphQL::Types::Int, null: false, description: 'Year of the data.'
    end
  end
end
