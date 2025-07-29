# frozen_string_literal: true

module Mutations
  module Ai
    module Agents
      class Update < Base
        graphql_name 'AiAgentUpdate'

        include FindsProject

        argument :agent_id, Types::GlobalIDType[::Ai::Agent],
          required: true,
          description: 'ID of the agent.'

        argument :name, GraphQL::Types::String,
          required: false,
          description: 'Name of the agent.'

        argument :prompt, GraphQL::Types::String,
          required: false,
          description: 'Prompt for the agent.'

        def resolve(**args)
          authorized_find!(args[:project_path])
          agent = find_agent(args[:agent_id])

          updated_agent = ::Ai::Agents::UpdateAgentService.new(agent, args[:name], args[:prompt]).execute

          {
            agent: updated_agent.errors.any? ? nil : updated_agent,
            errors: errors_on_object(updated_agent)
          }
        end
      end
    end
  end
end
