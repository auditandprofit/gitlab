# frozen_string_literal: true

module Mutations
  module Ai
    module Catalog
      module Agent
        class Update < BaseMutation
          graphql_name 'AiCatalogAgentUpdate'

          field :item,
            ::Types::Ai::Catalog::ItemInterface,
            null: true,
            description: 'Agent that was updated.'

          argument :id, ::Types::GlobalIDType[::Ai::Catalog::Item],
            required: true,
            description: 'Global ID of the catalog Agent to update.'

          argument :description, GraphQL::Types::String,
            required: false,
            description: 'Description for the agent.'

          argument :name, GraphQL::Types::String,
            required: false,
            description: 'Name for the agent.'

          argument :public, GraphQL::Types::Boolean,
            required: false,
            description: 'Whether the item is publicly visible in the catalog.'

          argument :system_prompt, GraphQL::Types::String,
            required: false,
            description: 'System prompt for the agent.'

          argument :tools, [::Types::GlobalIDType[::Ai::Catalog::BuiltInTool]],
            required: false,
            loads: Types::Ai::Catalog::BuiltInToolType,
            description: 'List of GitLab tools enabled for the agent.'

          argument :user_prompt, GraphQL::Types::String,
            required: false,
            description: 'User prompt for the agent.'

          authorize :admin_ai_catalog_item

          def resolve(args)
            agent = authorized_find!(id: args.delete(:id))
            params = args.merge(agent: agent)

            result = ::Ai::Catalog::Agents::UpdateService.new(
              project: agent.project,
              current_user: current_user,
              params: params
            ).execute

            item = result.payload[:item]
            item.reset unless result.success?

            {
              item: item,
              errors: result.errors
            }
          end
        end
      end
    end
  end
end
