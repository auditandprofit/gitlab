# frozen_string_literal: true

module Mutations
  module Ai
    module Agents
      class Destroy < Base
        graphql_name 'AiAgentDestroy'

        include FindsProject

        argument :agent_id, ::Types::GlobalIDType[::Ai::Agent],
          required: true,
          description: 'Global ID of the AI Agent to be deleted.'

        field :message, GraphQL::Types::String,
          null: true,
          description: 'AI Agent deletion result message.'

        def resolve(**args)
          authorized_find!(args[:project_path])
          agent = find_agent(args[:agent_id])

          return { errors: ['AI Agent not found'] } unless agent

          result = ::Ai::Agents::DestroyAgentService.new(agent, current_user).execute

          {
            message: result.success? ? result[:message] : nil,
            errors: result.error? ? Array.wrap(result[:message]) : []
          }
        end
      end
    end
  end
end
