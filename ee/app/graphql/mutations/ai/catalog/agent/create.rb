# frozen_string_literal: true

module Mutations
  module Ai
    module Catalog
      module Agent
        class Create < BaseMutation
          graphql_name 'AiCatalogAgentCreate'

          field :item,
            ::Types::Ai::Catalog::ItemInterface,
            null: true,
            description: 'Item created.'

          argument :description, GraphQL::Types::String,
            required: true,
            description: 'Description for the agent.'

          argument :name, GraphQL::Types::String,
            required: true,
            description: 'Name for the agent.'

          argument :project_id, ::Types::GlobalIDType[::Project],
            required: true,
            description: 'Project for the agent.'

          argument :public, GraphQL::Types::Boolean,
            required: true,
            description: 'Whether the agent is publicly visible in the catalog.'

          argument :system_prompt, GraphQL::Types::String,
            required: true,
            description: 'System prompt for the agent.'

          argument :tools, [::Types::GlobalIDType[::Ai::Catalog::BuiltInTool]],
            required: false,
            loads: Types::Ai::Catalog::BuiltInToolType,
            description: 'List of GitLab tools enabled for the agent.'

          argument :user_prompt, GraphQL::Types::String,
            required: true,
            description: 'User prompt for the agent.'

          authorize :admin_ai_catalog_item

          def resolve(args)
            project = authorized_find!(id: args[:project_id])

            service_args = args.except(:project_id)

            result = ::Ai::Catalog::Agents::CreateService.new(
              project: project,
              current_user: current_user,
              params: service_args
            ).execute

            { item: result.payload[:item], errors: result.errors }
          end
        end
      end
    end
  end
end
