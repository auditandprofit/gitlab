# frozen_string_literal: true

module Types
  module Ai
    module Agents
      # rubocop: disable Graphql/AuthorizeTypes -- authorization in resolver/mutation
      class AgentType < ::Types::BaseObject
        graphql_name 'AiAgent'
        description 'An AI agent'

        present_using ::Ai::AgentPresenter

        field :created_at, Types::TimeType, null: false, description: 'Date of creation.'
        field :id, GraphQL::Types::ID, null: false, description: 'ID of the agent.'
        field :latest_version, ::Types::Ai::Agents::AgentVersionType, null: true,
          description: 'Latest version of the agent.'
        field :name, GraphQL::Types::String, null: false, description: 'Name of the agent.'
        field :route_id, GraphQL::Types::Int, null: false, description: 'Route ID of the agent.'
        field :versions, [Types::Ai::Agents::AgentVersionType], null: true, description: 'Versions of the agent.'
      end
      # rubocop: enable Graphql/AuthorizeTypes
    end
  end
end
