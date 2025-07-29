# frozen_string_literal: true

module Resolvers
  module Ai
    module Agents
      class FindAgentResolver < BaseResolver
        extension ::Gitlab::Graphql::Limit::FieldCallCount, limit: 1

        type ::Types::Ai::Agents::AgentType.connection_type, null: true

        def resolve(**_args)
          return unless Ability.allowed?(current_user, :read_ai_agents, object)

          ::Ai::Agents::AgentFinder.new(object).execute
        end
      end
    end
  end
end
