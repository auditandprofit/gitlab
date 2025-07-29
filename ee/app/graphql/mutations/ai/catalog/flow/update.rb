# frozen_string_literal: true

module Mutations
  module Ai
    module Catalog
      module Flow
        class Update < BaseMutation
          graphql_name 'AiCatalogFlowUpdate'

          field :item,
            ::Types::Ai::Catalog::ItemInterface,
            null: true,
            description: 'Flow that was updated.'

          argument :id, ::Types::GlobalIDType[::Ai::Catalog::Item],
            required: true,
            description: 'Global ID of the catalog flow to update.'

          argument :description, GraphQL::Types::String,
            required: false,
            description: 'Description for the flow.'

          argument :name, GraphQL::Types::String,
            required: false,
            description: 'Name for the flow.'

          argument :public, GraphQL::Types::Boolean,
            required: false,
            description: 'Whether the flow is publicly visible in the catalog.'

          authorize :admin_ai_catalog_item

          def resolve(args)
            flow = authorized_find!(id: args[:id])

            params = args.slice(:name, :description, :public).merge(flow: flow)

            result = ::Ai::Catalog::Flows::UpdateService.new(
              project: flow.project,
              current_user: current_user,
              params: params
            ).execute

            item = result.payload[:flow]
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
