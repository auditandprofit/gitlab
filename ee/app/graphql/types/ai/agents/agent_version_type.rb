# frozen_string_literal: true

module Types
  module Ai
    module Agents
      # rubocop: disable Graphql/AuthorizeTypes -- authorization in authorization in resolver/mutation
      class AgentVersionType < ::Types::BaseObject
        graphql_name 'AiAgentVersion'
        description 'Version of an AI Agent'

        field :created_at, Types::TimeType, null: false, description: 'Timestamp when the agent version was created.'
        field :id, GraphQL::Types::ID, null: false, description: 'ID of the agent version.'
        field :model, GraphQL::Types::String, null: false, description: 'Model of the agent.'
        field :prompt, GraphQL::Types::String, null: false, description: 'Prompt of the agent.'
      end
      # rubocop: enable Graphql/AuthorizeTypes
    end
  end
end
