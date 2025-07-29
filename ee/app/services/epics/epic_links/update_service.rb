# frozen_string_literal: true

module Epics
  module EpicLinks
    class UpdateService < BaseService
      attr_reader :epic
      private :epic

      def initialize(epic, user, params)
        @epic = epic
        @current_user = user
        @params = params
      end

      def execute
        unless can?(current_user, :admin_epic_tree_relation, epic)
          return error('Epic not found for given params', 404)
        end

        move_epic!
        success
      rescue ActiveRecord::RecordNotFound, ::Epics::SyncAsWorkItem::SyncAsWorkItemError => e
        message =
          if e.is_a?(ActiveRecord::RecordNotFound)
            _('Epic not found for given params')
          else
            Gitlab::ErrorTracking.track_exception(e, moving_epic_id: epic.id)
            Gitlab::EpicWorkItemSync::Logger.error(error: e)

            _("Couldn't reorder child due to an internal error.")
          end

        error(message, 422)
      end

      private

      def move_epic!
        return unless params[:move_after_id] || params[:move_before_id]

        before_epic = Epic.in_parents(epic.parent_id).find(params[:move_before_id]) if params[:move_before_id]
        after_epic = Epic.in_parents(epic.parent_id).find(params[:move_after_id]) if params[:move_after_id]

        ::ApplicationRecord.transaction do
          epic.move_between(before_epic, after_epic)
          epic.save!(touch: false)
          sync_work_items_relative_position!(before_epic, after_epic, epic)
        end
      end

      def sync_work_items_relative_position!(before_epic, after_epic, epic)
        return true unless sync_work_item_parent_links?(epic, before_epic, after_epic)

        parent_link = epic.work_item.parent_link

        parent_link.move_between(before_epic&.work_item&.parent_link, after_epic&.work_item&.parent_link)
        return true if parent_link.save!(touch: false)

        error = "Not able to sync child relative position: #{parent_link.errors.full_messages.to_sentence}"
        raise SyncAsWorkItem::SyncAsWorkItemError, error
      end

      def sync_work_item_parent_links?(epic, before_epic, after_epic)
        return false unless epic.work_item&.parent_link.present?
        return false if after_epic && after_epic.work_item&.parent_link.blank?
        return false if before_epic && before_epic.work_item&.parent_link.blank?

        true
      end
    end
  end
end
