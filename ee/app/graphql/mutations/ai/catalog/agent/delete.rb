# frozen_string_literal: true

module Mutations
  module Ai
    module Catalog
      module Agent
        class Delete < BaseMutation
          graphql_name 'AiCatalogAgentDelete'

          field :success, GraphQL::Types::Boolean,
            null: false,
            description: 'Returns true if catalog Agent was successfully deleted.'

          argument :id, ::Types::GlobalIDType[::Ai::Catalog::Item],
            required: true,
            description: 'Global ID of the catalog Agent to delete.'

          authorize :admin_ai_catalog_item

          def resolve(args)
            agent = authorized_find!(id: args[:id])

            result = ::Ai::Catalog::Agents::DestroyService.new(
              project: agent.project,
              current_user: current_user,
              params: { item: agent }).execute

            {
              success: result.success?,
              errors: Array(result.errors)
            }
          end
        end
      end
    end
  end
end
