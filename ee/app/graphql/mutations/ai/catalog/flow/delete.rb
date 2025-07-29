# frozen_string_literal: true

module Mutations
  module Ai
    module Catalog
      module Flow
        class Delete < BaseMutation
          graphql_name 'AiCatalogFlowDelete'

          field :success, GraphQL::Types::Boolean,
            null: false,
            description: 'Returns true if catalog flow was successfully deleted.'

          argument :id, ::Types::GlobalIDType[::Ai::Catalog::Item],
            required: true,
            description: 'Global ID of the catalog flow to delete.'

          authorize :admin_ai_catalog_item

          def resolve(args)
            flow = authorized_find!(id: args[:id])

            result = ::Ai::Catalog::Flows::DestroyService.new(
              project: flow.project,
              current_user: current_user,
              params: { item: flow }).execute

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
