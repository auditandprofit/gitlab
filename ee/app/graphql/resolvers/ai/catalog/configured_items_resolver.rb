# frozen_string_literal: true

module Resolvers
  module Ai
    module Catalog
      class ConfiguredItemsResolver < BaseResolver
        description 'Find AI Catalog items configured for use.'

        type ::Types::Ai::Catalog::ItemConsumerType.connection_type, null: false

        argument :project_id,
          ::Types::GlobalIDType[::Project],
          required: true,
          description: 'Project ID to retrieve configured AI Catalog items for.'

        def resolve(project_id:)
          return none unless ::Feature.enabled?(:global_ai_catalog, current_user)

          project = ::Project.find_by_id(project_id.model_id)
          return none unless Ability.allowed?(current_user, :read_ai_catalog_item_consumer, project)

          project.configured_ai_catalog_items
        end

        private

        def none
          ::Ai::Catalog::ItemConsumer.none
        end
      end
    end
  end
end
