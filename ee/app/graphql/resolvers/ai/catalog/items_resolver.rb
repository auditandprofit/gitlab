# frozen_string_literal: true

module Resolvers
  module Ai
    module Catalog
      class ItemsResolver < BaseResolver
        include LooksAhead

        description 'AI Catalog items.'

        type ::Types::Ai::Catalog::ItemInterface.connection_type, null: false

        argument :item_type, ::Types::Ai::Catalog::ItemTypeEnum,
          required: false,
          description: 'Type of items to retrieve.'

        def resolve_with_lookahead(item_type: nil)
          return ::Ai::Catalog::Item.none unless ::Feature.enabled?(:global_ai_catalog, current_user)

          items = ::Ai::Catalog::Item.not_deleted
          items = items.with_item_type(item_type) if item_type
          apply_lookahead(items)
        end

        def preloads
          {
            versions: :versions,
            # TODO: Optimize loading of latest version https://gitlab.com/gitlab-org/gitlab/-/issues/554673
            latest_version: :latest_version
          }
        end
      end
    end
  end
end
