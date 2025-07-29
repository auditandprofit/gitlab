# frozen_string_literal: true

module Types
  module Ai
    module Catalog
      class AgentVersionType < ::Types::BaseObject
        graphql_name 'AiCatalogAgentVersion'
        description 'An AI catalog agent version'
        authorize :read_ai_catalog_item

        implements ::Types::Ai::Catalog::VersionInterface

        field :system_prompt, GraphQL::Types::String, null: true,
          description: 'System prompt for the agent.'
        field :tools, ::Types::Ai::Catalog::BuiltInToolType.connection_type,
          null: false,
          description: 'List of GitLab tools enabled for the agent.'
        field :user_prompt, GraphQL::Types::String, null: true,
          description: 'User prompt for the agent.'

        def system_prompt
          object.definition['system_prompt']
        end

        def tools
          tool_ids = Array(object.definition['tools'])
          return [] if tool_ids.empty?

          ::Ai::Catalog::BuiltInTool.where(id: tool_ids) # rubocop:disable CodeReuse/ActiveRecord -- Not a database query
        end

        def user_prompt
          object.definition['user_prompt']
        end
      end
    end
  end
end
