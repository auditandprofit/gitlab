# frozen_string_literal: true

module Types
  module Ai
    module Catalog
      class AgentType < ::Types::BaseObject
        graphql_name 'AiCatalogAgent'
        description 'An AI catalog agent'
        authorize :read_ai_catalog_item

        implements ::Types::Ai::Catalog::ItemInterface
      end
    end
  end
end
