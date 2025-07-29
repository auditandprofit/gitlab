# frozen_string_literal: true

module Types
  module Analytics
    module AiUsage
      class AiUsageDataType < BaseObject
        graphql_name 'AiUsageData'
        description "Usage data for events stored in the default PostgreSQL database. " \
          "Data retained for three months. Requires a personal access token. " \
          "Endpoint works only on the top-level group. Ultimate with GitLab Duo Enterprise only."

        authorize :read_enterprise_ai_analytics

        field :code_suggestion_events,
          description: 'Events related to code suggestions.',
          resolver: ::Resolvers::Analytics::AiUsage::CodeSuggestionEventsResolver

        field :all,
          description: 'All Duo usage events.',
          resolver: ::Resolvers::Analytics::AiUsage::UsageEventsResolver
      end
    end
  end
end
