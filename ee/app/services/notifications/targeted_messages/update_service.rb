# frozen_string_literal: true

module Notifications
  module TargetedMessages
    class UpdateService < BaseService
      def initialize(targeted_message, params)
        super(params)

        @targeted_message = targeted_message
      end

      def execute
        parse_namespaces

        success = Notifications::TargetedMessage.transaction do
          @targeted_message.assign_attributes(params)
          raise ActiveRecord::Rollback unless @targeted_message.valid?

          existing_namespace_ids = @targeted_message.namespace_ids
          namespace_to_delete = existing_namespace_ids - parsed_namespaces[:valid_namespace_ids]
          namespace_to_create = parsed_namespaces[:valid_namespace_ids] - existing_namespace_ids

          @targeted_message.targeted_message_namespaces.where(namespace_id: namespace_to_delete).delete_all # rubocop:disable CodeReuse/ActiveRecord -- necessary for this service

          namespace_to_create.each_slice(1000) do |namespace_ids|
            namespace_data = namespace_ids.map do |namespace_id|
              {
                targeted_message_id: @targeted_message.id,
                namespace_id: namespace_id
              }
            end

            Notifications::TargetedMessageNamespace.insert_all(namespace_data)
          end
        end

        if success
          handle_success
        else
          handle_failure
        end
      end

      private

      def handle_success
        if partial_success?
          ServiceResponse.error(
            message: format(
              s_('TargetedMessages|Targeted message was successfully updated. But %{invalid_namespace_ids_message}'),
              invalid_namespace_ids_message: parsed_namespaces[:message]
            ),
            payload: targeted_message,
            reason: FOUND_INVALID_NAMESPACES
          )
        else
          success
        end
      end
    end
  end
end
