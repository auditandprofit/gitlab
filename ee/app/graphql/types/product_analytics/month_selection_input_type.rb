# frozen_string_literal: true

module Types
  module ProductAnalytics
    class MonthSelectionInputType < BaseInputObject
      graphql_name 'MonthSelectionInput'
      description "A year and month input for querying product analytics usage data."

      argument :month, GraphQL::Types::Int,
        required: true,
        description: 'Month of the period to return.'

      argument :year, GraphQL::Types::Int,
        required: true,
        description: 'Year of the period to return.'
    end
  end
end
