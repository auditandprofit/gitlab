# frozen_string_literal: true

module Types
  module Ai
    module Catalog
      module ItemInterface
        include Types::BaseInterface

        RESOLVE_TYPES = {
          ::Ai::Catalog::Item::AGENT_TYPE => ::Types::Ai::Catalog::AgentType,
          ::Ai::Catalog::Item::FLOW_TYPE => ::Types::Ai::Catalog::FlowType
        }.freeze

        graphql_name 'AiCatalogItem'
        description 'An AI catalog item'

        connection_type_class ::Types::CountableConnectionType

        field :created_at, ::Types::TimeType, null: false, description: 'Date of creation.'
        field :description, GraphQL::Types::String, null: false, description: 'Description of the item.'
        field :id, GraphQL::Types::ID, null: false, description: 'ID of the item.'
        field :item_type,
          ItemTypeEnum,
          null: false,
          description: 'Type of the item.'
        field :name, GraphQL::Types::String, null: false, description: 'Name of the item.'
        field :project, ::Types::ProjectType, null: true, description: 'Project for the item.'
        field :public, GraphQL::Types::Boolean,
          null: false,
          description: 'Whether the item is publicly visible in the catalog.'
        field :versions, ::Types::Ai::Catalog::VersionInterface.connection_type,
          null: true,
          description: 'Versions of the item.'
        field :latest_version, ::Types::Ai::Catalog::VersionInterface,
          null: true,
          description: 'Latest version of the item.'

        orphan_types ::Types::Ai::Catalog::AgentType
        orphan_types ::Types::Ai::Catalog::FlowType

        def self.resolve_type(item, _context)
          RESOLVE_TYPES[item.item_type.to_sym] or raise "Unknown catalog item type: #{item.item_type}" # rubocop:disable Style/AndOr -- Syntax error when || is used
        end
      end
    end
  end
end
