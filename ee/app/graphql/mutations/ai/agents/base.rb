# frozen_string_literal: true

module Mutations
  module Ai
    module Agents
      class Base < BaseMutation
        authorize :write_ai_agents

        argument :project_path, GraphQL::Types::ID,
          required: true,
          description: "Project to which the agent belongs."

        field :agent,
          Types::Ai::Agents::AgentType,
          null: true,
          description: 'Agent after mutation.'

        def find_agent(agent_id)
          ::Gitlab::Graphql::Lazy.force(GitlabSchema.find_by_gid(agent_id))
        end
      end
    end
  end
end
