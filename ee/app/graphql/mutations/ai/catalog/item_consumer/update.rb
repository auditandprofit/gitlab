# frozen_string_literal: true

module Mutations
  module Ai
    module Catalog
      module ItemConsumer
        class Update < BaseMutation
          graphql_name 'AiCatalogItemConsumerUpdate'

          field :item_consumer,
            ::Types::Ai::Catalog::ItemConsumerType,
            null: true,
            description: 'Item consumer that was updated.'

          argument :id, ::Types::GlobalIDType[::Ai::Catalog::ItemConsumer],
            required: true,
            description: 'Global ID of the catalog item consumer to update.'

          argument :enabled, GraphQL::Types::Boolean,
            required: false,
            description: 'Whether the flow is enabled in the group or project.'

          argument :locked, GraphQL::Types::Boolean,
            required: false,
            description: 'Whether the configuration is locked.'

          authorize :admin_ai_catalog_item_consumer

          def resolve(args)
            item_consumer = authorized_find!(id: args[:id])

            params = args.slice(:enabled, :locked)

            result = ::Ai::Catalog::ItemConsumers::UpdateService.new(
              item_consumer,
              current_user,
              params
            ).execute

            item_consumer = result.payload[:item_consumer]
            item_consumer.reset unless result.success?

            {
              item_consumer: item_consumer,
              errors: result.errors
            }
          end
        end
      end
    end
  end
end
