# frozen_string_literal: true

module Types
  module Ai
    module Catalog
      class ItemConsumerType < ::Types::BaseObject
        graphql_name 'AiCatalogItemConsumer'
        description 'An AI catalog item configuration'
        authorize :read_ai_catalog_item_consumer

        connection_type_class ::Types::CountableConnectionType

        field :enabled, GraphQL::Types::Boolean,
          null: false,
          description: 'Indicates whether the catalog item is enabled or not.'
        field :group, ::Types::GroupType,
          null: true,
          description: 'Group in which the catalog item is configured.'
        field :id, GraphQL::Types::ID,
          null: false,
          description: 'ID of the configuration item.'
        field :item, ::Types::Ai::Catalog::ItemInterface,
          null: true,
          description: 'Configuration catalog item.'
        field :locked, GraphQL::Types::Boolean,
          null: false,
          description: 'Indicates whether the catalog item configuration is locked or can be overridden.'
        field :organization, ::Types::Organizations::OrganizationType,
          null: true,
          description: 'Organization in which the catalog item is configured.'
        field :project, ::Types::ProjectType,
          null: true,
          description: 'Project in which the catalog item is configured.'

        def item
          ::Gitlab::Graphql::Loaders::BatchModelLoader.new(::Ai::Catalog::Item, object.ai_catalog_item_id).find
        end
      end
    end
  end
end
