# frozen_string_literal: true

module Epics
  module Strategies
    class BaseDatesStrategy
      def initialize(epics)
        @epics = epics
      end

      # rubocop: disable CodeReuse/ActiveRecord
      def source_milestones_query
        ::Milestone
          .joins(issues: :epic_issue)
          .where("epic_issues.epic_id = epics.id")
      end
      # rubocop: enable CodeReuse/ActiveRecord

      def update_epic_work_items(epics)
        work_items_dates = build_work_items_date_sources(epics)
        return if work_items_dates.blank?

        WorkItems::DatesSource.upsert_all(work_items_dates, unique_by: :issue_id)
      end

      def build_work_items_date_sources(epics)
        epics.flat_map do |epic|
          {
            issue_id: epic.issue_id,
            namespace_id: epic.group_id,
            start_date_is_fixed: epic.start_date_is_fixed.present?,
            due_date_is_fixed: epic.due_date_is_fixed.present?,
            start_date: epic.start_date,
            due_date: epic.due_date,
            start_date_sourcing_work_item_id: epic.start_date_sourcing_epic&.issue_id,
            start_date_sourcing_milestone_id: epic.start_date_sourcing_milestone_id,
            due_date_sourcing_work_item_id: epic.due_date_sourcing_epic&.issue_id,
            due_date_sourcing_milestone_id: epic.due_date_sourcing_milestone_id,
            start_date_fixed: epic.start_date_fixed,
            due_date_fixed: epic.due_date_fixed
          }
        end
      end
    end
  end
end
