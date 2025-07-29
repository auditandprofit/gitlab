# frozen_string_literal: true

module Epics
  module EpicLinks
    class DestroyService < IssuableLinks::DestroyService
      extend ::Gitlab::Utils::Override

      attr_reader :child_epic, :parent_epic, :synced_epic
      private :child_epic, :parent_epic

      def initialize(child_epic, user, synced_epic: false)
        @child_epic = child_epic
        @parent_epic = child_epic&.parent
        @current_user = user
        @synced_epic = synced_epic
      end

      private

      def remove_relation
        ::ApplicationRecord.transaction do
          # When we're syncing from the work item, we destroy the `WorkItems::ParentLink` record.
          # On the epic side we modify the `Epic` record, and it would set a new `updated_at`. This would lead
          # to WorkItem.updated_at and Epic.updated_at being out of sync.
          #
          # When syncing the work item from the epic side, we update the work_item.updated_at when the Note gets
          # created. This is to have consistency with the previous behaviour.
          child_epic.assign_attributes(parent_id: nil, updated_by: current_user)
          child_epic.save!(touch: synced_epic ? false : true)

          destroy_work_item_parent_link!
        end
      end

      def create_notes
        return unless parent_epic && !synced_epic

        SystemNoteService.change_epics_relation(parent_epic, child_epic, current_user, 'unrelate_epic')
      end

      def permission_to_remove_relation?
        return true if synced_epic

        child_epic.present? &&
          parent_epic.present? &&
          can?(current_user, :read_epic_relation, parent_epic) &&
          can?(current_user, :admin_epic_relation, child_epic)
      end

      def not_found_message
        'No Epic found for given params'
      end

      override :after_destroy
      def after_destroy
        super

        return if synced_epic

        ::Epics::UpdateDatesService.new([parent_epic, child_epic]).execute
      end

      def destroy_work_item_parent_link!
        return if synced_epic || child_epic.work_item.blank?

        parent_link = child_epic.work_item.parent_link
        return unless parent_link.present?

        service_response = ::WorkItems::ParentLinks::DestroyService
                              .new(parent_link, current_user, { synced_work_item: true }).execute
        return if service_response[:status] == :success

        synced_work_item_error!(service_response[:message])
      end

      def synced_work_item_error!(error_msg)
        Gitlab::EpicWorkItemSync::Logger.error(
          message: 'Not able to remove epic parent', error_message: error_msg, group_id: child_epic.group.id,
          child_id: child_epic.id, parent_id: parent_epic.id
        )
        raise ActiveRecord::Rollback
      end
    end
  end
end
