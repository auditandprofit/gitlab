# frozen_string_literal: true

module Mutations
  module Ai
    module Agents
      class Create < Base
        graphql_name 'AiAgentCreate'

        include FindsProject

        argument :name, GraphQL::Types::String,
          required: true,
          description: 'Name of the agent.'

        argument :prompt, GraphQL::Types::String,
          required: true,
          description: 'Prompt for the agent.'

        def resolve(**args)
          project = authorized_find!(args[:project_path])

          agent = ::Ai::Agents::CreateAgentService.new(project, args[:name], args[:prompt]).execute

          {
            agent: agent.persisted? ? agent : nil,
            errors: errors_on_object(agent) + errors_on_object(agent.versions.first)
          }
        end
      end
    end
  end
end
