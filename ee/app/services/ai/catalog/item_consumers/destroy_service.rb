# frozen_string_literal: true

module Ai
  module Catalog
    module ItemConsumers
      class DestroyService
        def initialize(item_consumer, current_user)
          @current_user = current_user
          @item_consumer = item_consumer
        end

        def execute
          return error_no_permissions unless allowed?

          return ServiceResponse.success(payload: { item_consumer: item_consumer }) if item_consumer.destroy

          error(item_consumer.errors.full_messages)
        end

        private

        attr_reader :current_user, :item_consumer

        def allowed?
          Ability.allowed?(current_user, :admin_ai_catalog_item_consumer, item_consumer)
        end

        def error_no_permissions
          error('You have insufficient permissions to delete this item consumer')
        end

        def error(message)
          ServiceResponse.error(message: Array(message))
        end
      end
    end
  end
end
