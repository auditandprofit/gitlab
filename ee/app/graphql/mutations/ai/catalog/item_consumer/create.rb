# frozen_string_literal: true

module Mutations
  module Ai
    module Catalog
      module ItemConsumer
        class Create < BaseMutation
          graphql_name 'AiCatalogItemConsumerCreate'

          field :item_consumer,
            ::Types::Ai::Catalog::ItemConsumerType,
            null: true,
            description: 'Item configuration created.'

          argument :item_id, ::Types::GlobalIDType[::Ai::Catalog::Item],
            required: true,
            description: 'Item to configure.'

          argument :enabled, GraphQL::Types::Boolean,
            required: false,
            description: 'Whether to enable the item.'

          argument :locked, GraphQL::Types::Boolean,
            required: false,
            description: 'Whether to lock the item configuration (groups only).'

          argument :target, Types::Ai::Catalog::ItemConsumerTargetInputType,
            required: true,
            description: 'Target in which the catalog item is configured.'

          authorize :admin_ai_catalog_item_consumer

          def resolve(item_id:, target:, enabled: true, locked: true)
            group_id = target[:group_id]
            group = group_id ? authorized_find!(id: group_id) : nil
            project_id = target[:project_id]
            project = project_id ? authorized_find!(id: project_id) : nil
            item = GitlabSchema.find_by_gid(item_id).sync

            raise_resource_not_available_error! unless item.flow? && allowed?(item)

            result = ::Ai::Catalog::ItemConsumers::CreateService.new(
              container: group || project,
              current_user: current_user,
              params: {
                item: item,
                enabled: enabled,
                locked: locked
              }
            ).execute

            { item_consumer: result.payload&.dig(:item_consumer), errors: result.errors }
          end

          private

          def allowed?(item)
            Ability.allowed?(current_user, :read_ai_catalog_item, item)
          end
        end
      end
    end
  end
end
