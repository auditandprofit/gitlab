# frozen_string_literal: true

module EE
  module Resolvers
    module Users
      module RecentlyViewedItemsResolver
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        override :available_types
        def available_types
          super + [::Gitlab::Search::RecentEpics]
        end
      end
    end
  end
end
