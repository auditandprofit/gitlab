# frozen_string_literal: true

module Epics
  module RelatedEpicLinks
    class DestroyService < ::IssuableLinks::DestroyService
      include UsageDataHelper
      include Gitlab::Utils::StrongMemoize

      attr_reader :epic, :link_type, :synced_epic

      def initialize(link, epic, user, synced_epic: false)
        @link = link
        @current_user = user
        @source = link.source
        @target = link.target
        @link_type = link.link_type
        @epic = epic
        @synced_epic = synced_epic
      end

      def execute
        return super unless epic.work_item && !synced_epic

        ApplicationRecord.transaction do
          result = super
          sync_to_work_item! if result[:status] == :success
          result
        end

      rescue Epics::SyncAsWorkItem::SyncAsWorkItemError => error
        Gitlab::ErrorTracking.track_exception(error, epic_id: epic.id)

        error(_("Couldn't delete link due to an internal error."), 422)
      end

      private

      def permission_to_remove_relation?
        return true if synced_epic

        source_epic, target_epic = epic_is_link_source? ? [source, target] : [target, source]

        can?(current_user, :admin_epic_link_relation, source_epic) &&
          can?(current_user, :read_epic_link_relation, target_epic)
      end

      def track_event
        event_type = get_event_type

        return unless event_type

        track_related_epics_event_for(link_type: event_type, event_type: :removed, namespace: epic.group)
      end

      def get_event_type
        return unless epic_is_link_source? || epic_is_link_target?

        # If the link.link_type is of TYPE_BLOCKS and the epic in context is:
        # - epic_is_link_target? means the epic is blocked by other epic
        # - epic_is_link_source? it means the epic is blocking another epic
        if epic_is_link_target?
          Epic::RelatedEpicLink.inverse_link_type(link_type)
        else
          link_type
        end
      end

      def epic_is_link_source?
        strong_memoize(:epic_is_link_source) { epic == source }
      end

      def epic_is_link_target?
        strong_memoize(:epic_is_link_target) { epic == target }
      end

      def sync_to_work_item!
        return unless epic.work_item
        return unless source.issue_id && target.issue_id
        return unless WorkItems::RelatedWorkItemLink.for_source_and_target(source.work_item, target.work_item).present?

        item_ids = epic_is_link_source? ? [target.issue_id] : [source.issue_id]

        result = WorkItems::RelatedWorkItemLinks::DestroyService.new(epic.work_item, current_user, {
          item_ids: item_ids,
          extra_params: { synced_work_item: true }
        }).execute
        return result if result[:status] == :success

        Gitlab::EpicWorkItemSync::Logger.error(
          message: "Not able to destroy work item links",
          error_message: result[:message],
          group_id: epic.group.id,
          target_id: target.id,
          source_id: source.id
        )

        raise Epics::SyncAsWorkItem::SyncAsWorkItemError, result[:message]
      end

      def not_found_message
        'No Related Epic Link found'
      end

      def create_notes
        super unless synced_epic
      end
    end
  end
end
