# frozen_string_literal: true

module WorkItems
  module LegacyEpics
    class UpdateService
      include ErrorMapping

      def self.constructor_container_arg(value)
        { group: value }
      end

      def initialize(group:, perform_spam_check: true, current_user: nil, params: {})
        @group = group
        @current_user = current_user
        @params = params.to_hash.symbolize_keys!
        @perform_spam_check = perform_spam_check
      end

      def execute(epic)
        # WorkItems::UpdateService will return an error if we try to assign the same parent twice
        params.delete(:parent_id) if params[:parent_id] == epic&.parent&.id

        return epic unless can_perform_update?(epic)

        transformed_params, widget_params =
          ::Gitlab::WorkItems::LegacyEpics::WidgetParamsExtractor.new(params).extract

        service = ::WorkItems::UpdateService.new(
          container: group,
          perform_spam_check: perform_spam_check,
          current_user: current_user,
          params: transformed_params,
          widget_params: widget_params
        )

        transform_result(service.execute(epic.issue))
      end

      private

      def transform_result(result)
        new_epic = result[:work_item]&.synced_epic&.reset || Epic.new

        return new_epic if result[:status] == :success

        messages = Array(result[:message])
        messages.each do |msg|
          new_epic.errors.add(:base, msg.include?(WORK_ITEM_NOT_FOUND_ERROR) ? EPIC_NOT_FOUND_ERROR : msg)
        end

        new_epic
      end

      def can_perform_update?(epic)
        return false unless current_user.can?(:update_epic, epic)
        return false if params[:parent_id] && !current_user.can?(:update_epic, Epic.find(params[:parent_id]))

        true
      end

      attr_reader :group, :current_user, :params, :perform_spam_check
    end
  end
end
