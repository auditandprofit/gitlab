# frozen_string_literal: true

module Resolvers
  module Ai
    module Catalog
      class ItemResolver < BaseResolver
        description 'Find an AI Catalog item.'

        type ::Types::Ai::Catalog::ItemInterface, null: true

        argument :id,
          ::Types::GlobalIDType[::Ai::Catalog::Item],
          required: true,
          description: 'Global ID of the catalog item to find.'

        def resolve(id:)
          return unless ::Feature.enabled?(:global_ai_catalog, current_user)

          GitlabSchema.find_by_gid(id)
        end
      end
    end
  end
end
