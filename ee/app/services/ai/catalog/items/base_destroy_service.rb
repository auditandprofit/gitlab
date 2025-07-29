# frozen_string_literal: true

module Ai
  module Catalog
    module Items
      class BaseDestroyService < Ai::Catalog::BaseService
        def initialize(project:, current_user:, params:)
          @item = params[:item]
          super
        end

        def execute
          return error_no_permissions unless allowed?
          return error_no_item unless valid?

          if delete_item
            track_ai_item_events('delete_ai_catalog_item', item.item_type)
            return success
          end

          error_response
        end

        private

        attr_reader :item

        def valid?
          !!item
        end

        def success
          ServiceResponse.success
        end

        def error_no_item
          error('Item not found')
        end

        def error_response
          error(item.errors.full_messages)
        end

        def delete_item
          return item.soft_delete if item.consumers.any?

          item.destroy
        end
      end
    end
  end
end
