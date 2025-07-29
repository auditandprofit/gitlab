# frozen_string_literal: true

module EpicIssues
  class DestroyService < IssuableLinks::DestroyService
    extend ::Gitlab::Utils::Override

    attr_reader :synced_epic

    def initialize(link, user, synced_epic: false)
      @link = link
      @current_user = user
      @source = link.epic
      @target = link.issue
      @synced_epic = synced_epic
    end

    def execute
      super
    rescue Epics::SyncAsWorkItem::SyncAsWorkItemError => error
      Gitlab::ErrorTracking.track_exception(error, epic_id: source.id)

      error(_("Couldn't delete link due to an internal error."), 422)
    end

    private

    def remove_relation
      return super unless source.work_item

      ::ApplicationRecord.transaction do
        super
        sync_to_work_item!
      end
    end

    override :after_destroy
    def after_destroy
      super

      Epics::UpdateDatesService.new([link.epic]).execute unless skip_update_dates_service?

      ::GraphqlTriggers.issuable_epic_updated(@target)
    end

    def track_event
      ::Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_issue_removed(
        author: current_user,
        namespace: source.group
      )
    end

    def permission_to_remove_relation?
      return true if synced_epic

      can?(current_user, :admin_issue_relation, target) && can?(current_user, :read_epic, source)
    end

    def create_notes
      return if synced_epic

      SystemNoteService.epic_issue(source, target, current_user, :removed)
      SystemNoteService.issue_on_epic(target, source, current_user, :removed)
    end

    def sync_to_work_item!
      return unless source.issue_id.present? && !synced_epic

      parent_link = WorkItems::ParentLink.for_children(link.issue_id).first
      return unless parent_link.present?

      service_response =
        ::WorkItems::ParentLinks::DestroyService.new(parent_link, current_user, { synced_work_item: true }).execute
      return if service_response[:status] == :success

      synced_work_item_error!(service_response[:message])
    end

    def synced_work_item_error!(error_msg)
      Gitlab::EpicWorkItemSync::Logger.error(
        message: 'Not able to destroy work item links',
        error_message: error_msg,
        group_id: source.group.id,
        epic_id: source.id,
        issue_id: target.id
      )

      raise Epics::SyncAsWorkItem::SyncAsWorkItemError, error_msg
    end

    def skip_update_dates_service?
      synced_epic && source.work_item.present?
    end
  end
end
