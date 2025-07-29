# frozen_string_literal: true

module Types
  module Analytics
    module AiMetrics
      # rubocop: disable Graphql/AuthorizeTypes -- always authorized by Resolver
      # rubocop: disable GraphQL/ExtractType -- no value for now
      class NamespaceMetricsType < BaseObject
        graphql_name 'AiMetrics'
        description "Requires ClickHouse. Premium and Ultimate with GitLab Duo Pro and Enterprise only."

        field :code_contributors_count, GraphQL::Types::Int,
          description: 'Number of code contributors.',
          null: true
        field :code_suggestions,
          resolver: Resolvers::Analytics::AiMetrics::CodeSuggestionMetricsResolver,
          null: true,
          description: 'Code suggestions metrics.'
        field :code_suggestions_accepted_count, GraphQL::Types::Int,
          description: 'Total count of code suggestions accepted by code contributors.',
          null: true,
          deprecated: { reason: 'moved to codeSuggestions field', milestone: '18.0' }
        field :code_suggestions_contributors_count, GraphQL::Types::Int,
          description: 'Number of code contributors who used GitLab Duo Code Suggestions features.',
          null: true,
          deprecated: { reason: 'moved to codeSuggestions field', milestone: '18.0' }
        field :code_suggestions_shown_count, GraphQL::Types::Int,
          description: 'Total count of code suggestions shown to code contributors.',
          null: true,
          deprecated: { reason: 'moved to codeSuggestions field', milestone: '18.0' }
        field :duo_assigned_users_count, GraphQL::Types::Int,
          description: 'Total assigned Duo Pro and Enterprise seats. Ignores time period filter. Returns current data.',
          null: true
        field :duo_chat_contributors_count, GraphQL::Types::Int,
          description: 'Number of contributors who used GitLab Duo Chat features.',
          null: true
        field :duo_used_count, GraphQL::Types::Int,
          description: 'Number of contributors who used any GitLab Duo feature.',
          null: true
        field :root_cause_analysis_users_count, GraphQL::Types::Int,
          description: 'Number of users using troubleshoot within a failed pipeline.',
          null: true
      end
      # rubocop: enable GraphQL/ExtractType
      # rubocop: enable Graphql/AuthorizeTypes
    end
  end
end
