# frozen_string_literal: true

module Resolvers
  module Ai
    module Agents
      class AgentDetailResolver < BaseResolver
        extension ::Gitlab::Graphql::Limit::FieldCallCount, limit: 1

        type ::Types::Ai::Agents::AgentType, null: true

        argument :id, ::Types::GlobalIDType[::Ai::Agent],
          required: true,
          description: 'ID of the Agent.'

        def resolve(id:)
          Gitlab::Graphql::Lazy.with_value(find_object(id: id)) do |ai_agent|
            ai_agent if Ability.allowed?(current_user, :read_ai_agents, ai_agent&.project)
          end
        end

        private

        def find_object(id:)
          GitlabSchema.find_by_gid(id)
        end
      end
    end
  end
end
