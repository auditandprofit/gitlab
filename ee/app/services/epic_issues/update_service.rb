# frozen_string_literal: true

module EpicIssues
  class UpdateService < BaseService
    attr_reader :epic_issue, :current_user, :params

    def initialize(epic_issue, user, params)
      @epic_issue = epic_issue
      @current_user = user
      @params = params
    end

    def execute
      return error(s_('Insufficient permissions to update relation'), 403) unless permission_to_update_relation?

      ApplicationRecord.transaction do
        move_issue! if move_after_id || move_before_id
      end

      success
    rescue Epics::SyncAsWorkItem::SyncAsWorkItemError => e
      Gitlab::ErrorTracking.track_exception(e, epic_issue_id: epic_issue.id)

      error(_("Couldn't reorder child due to an internal error."), 400)
    rescue ActiveRecord::RecordNotFound
      error(s_('Epic issue not found for given params'), 404)
    end

    private

    def permission_to_update_relation?
      can?(current_user, :admin_issue_relation, epic_issue.issue) && can?(current_user, :admin_epic_relation, epic)
    end

    def move_issue!
      before_epic_issue = epic.epic_issues.find(move_before_id) if move_before_id
      after_epic_issue = epic.epic_issues.find(move_after_id) if move_after_id

      epic_issue.move_between(before_epic_issue, after_epic_issue)

      sync_move_to_work_item!(before_epic_issue, after_epic_issue) if epic_issue.save!
    end

    def sync_move_to_work_item!(before_epic_issue, after_epic_issue)
      moving_parent_link, before_parent_link, after_parent_link = find_parent_links(before_epic_issue, after_epic_issue)
      return unless moving_parent_link && (before_parent_link || after_parent_link)

      moving_parent_link.move_between(before_parent_link, after_parent_link)
      return if moving_parent_link.save

      raise Epics::SyncAsWorkItem::SyncAsWorkItemError, moving_parent_link.errors
    end

    def find_parent_links(before_epic_issue, after_epic_issue)
      before_issue_id = before_epic_issue&.issue&.id
      after_issue_id = after_epic_issue&.issue&.id
      moving_issue_id = epic_issue.issue.id

      work_items_parent_link_map = WorkItems::ParentLink.for_children(
        [before_issue_id, after_issue_id, moving_issue_id].compact
      ).index_by(&:work_item_id)

      [
        work_items_parent_link_map[moving_issue_id],
        work_items_parent_link_map[before_issue_id],
        work_items_parent_link_map[after_issue_id]
      ]
    end

    def move_before_id
      params[:move_before_id]
    end

    def move_after_id
      params[:move_after_id]
    end

    def epic
      epic_issue.epic
    end
  end
end
