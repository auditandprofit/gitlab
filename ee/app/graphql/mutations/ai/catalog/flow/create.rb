# frozen_string_literal: true

module Mutations
  module Ai
    module Catalog
      module Flow
        class Create < BaseMutation
          graphql_name 'AiCatalogFlowCreate'

          include Gitlab::Graphql::Authorize::AuthorizeResource

          field :item,
            ::Types::Ai::Catalog::ItemInterface,
            null: true,
            description: 'Item created.'

          argument :description, GraphQL::Types::String,
            required: true,
            description: 'Description for the flow.'

          argument :name, GraphQL::Types::String,
            required: true,
            description: 'Name for the flow.'

          argument :project_id, ::Types::GlobalIDType[::Project],
            required: true,
            description: 'Project for the flow.'

          argument :public, GraphQL::Types::Boolean,
            required: true,
            description: 'Whether the flow is publicly visible in the catalog.'

          authorize :admin_ai_catalog_item

          def resolve(args)
            project = authorized_find!(id: args[:project_id])

            service_args = args.except(:project_id)
            result = ::Ai::Catalog::Flows::CreateService.new(
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
