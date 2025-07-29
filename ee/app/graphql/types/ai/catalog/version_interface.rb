# frozen_string_literal: true

module Types
  module Ai
    module Catalog
      module VersionInterface
        include Types::BaseInterface

        RESOLVE_TYPES = {
          ::Ai::Catalog::Item::AGENT_TYPE => ::Types::Ai::Catalog::AgentVersionType,
          ::Ai::Catalog::Item::FLOW_TYPE => ::Types::Ai::Catalog::FlowVersionType
        }.freeze

        graphql_name 'AiCatalogItemVersion'
        description 'An AI catalog item version'

        connection_type_class ::Types::CountableConnectionType

        field :id, GraphQL::Types::ID, null: false, description: 'ID of the item version.'
        field :updated_at, Types::TimeType, null: false, description: 'Timestamp of when the item version was updated.'
        field :created_at, Types::TimeType, null: false, description: 'Timestamp of when the item version was created.'
        field :published_at, Types::TimeType, null: true, method: :release_date,
          description: 'Timestamp of when the item version was published.'
        field :version_name, GraphQL::Types::String, null: true, method: :human_version,
          description: 'Version name of the item version.'

        orphan_types ::Types::Ai::Catalog::AgentVersionType
        orphan_types ::Types::Ai::Catalog::FlowVersionType

        def self.resolve_type(version, _context)
          item_type = version.item.item_type.to_sym

          RESOLVE_TYPES[item_type] or raise "Unknown catalog item type: #{item_type}" # rubocop:disable Style/AndOr -- Syntax error when || is used
        end
      end
    end
  end
end
