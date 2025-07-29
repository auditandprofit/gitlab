# frozen_string_literal: true

module Ai
  module Catalog
    module ItemConsumers
      class UpdateService
        def initialize(item_consumer, current_user, params)
          @current_user = current_user
          @item_consumer = item_consumer
          @params = params.slice(:enabled, :locked, :pinned_version_prefix)
        end

        def execute
          return error_no_permissions unless allowed?

          if item_consumer.update(params)
            ServiceResponse.success(payload: { item_consumer: item_consumer })
          else
            error_updating
          end
        end

        private

        attr_reader :current_user, :item_consumer, :params

        def allowed?
          Ability.allowed?(current_user, :admin_ai_catalog_item_consumer, item_consumer)
        end

        def error_no_permissions
          error('You have insufficient permission to update this item consumer')
        end

        def error(message)
          ServiceResponse.error(payload: { item_consumer: item_consumer }, message: Array(message))
        end

        def error_updating
          error(item_consumer.errors.full_messages.presence || 'Failed to update item consumer')
        end
      end
    end
  end
end
