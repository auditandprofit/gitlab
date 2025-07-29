# frozen_string_literal: true

module Types
  module Analytics
    module AiMetrics
      # rubocop: disable Graphql/AuthorizeTypes -- authorized by parent type
      # rubocop: disable GraphQL/ExtractType -- no value for now
      class CodeSuggestionMetricsType < BaseObject
        graphql_name 'codeSuggestionMetrics'
        description "Requires ClickHouse. Premium and Ultimate with GitLab Duo Pro and Enterprise only."

        field :accepted_count, GraphQL::Types::Int,
          description: 'Total count of code suggestions accepted.',
          null: true
        field :accepted_lines_of_code, GraphQL::Types::Int,
          description: 'Sum of lines of code from code suggestions accepted.',
          null: true
        field :contributors_count, GraphQL::Types::Int,
          description: 'Number of code contributors who used GitLab Duo Code Suggestions features.',
          null: true
        field :languages, [::GraphQL::Types::String],
          description: 'List of languages with at least one suggestion shown or accepted.',
          null: true
        field :shown_count, GraphQL::Types::Int,
          description: 'Total count of code suggestions shown.',
          null: true
        field :shown_lines_of_code, GraphQL::Types::Int,
          description: 'Sum of lines of code from code suggestions shown.',
          null: true
      end
      # rubocop: enable GraphQL/ExtractType
      # rubocop: enable Graphql/AuthorizeTypes
    end
  end
end
