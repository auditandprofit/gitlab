# frozen_string_literal: true

module Epics
  class UpdateDatesService < ::BaseService
    BATCH_SIZE = 100

    STRATEGIES = [
      Epics::Strategies::StartDateInheritedStrategy,
      Epics::Strategies::DueDateInheritedStrategy
    ].freeze

    def initialize(epics)
      @epics = epics
      @epics = Epic.id_in(@epics) unless @epics.is_a?(ActiveRecord::Relation)
    end

    def execute
      # We need to either calculate the rolledup dates from the legacy epic side and sync to the work item,
      # or calculate it on the work item side and sync to the legacy epic.
      # If we'd run the jobs on both sides, we could end up with a race condition.
      if @epics.first&.group&.work_item_epics_ssot_enabled?
        ::WorkItems::Widgets::RolledupDatesService::HierarchiesUpdateService
          .new(WorkItem.id_in(@epics.select(:issue_id)))
          .execute
      else
        @epics.each_batch(of: BATCH_SIZE) do |relation|
          STRATEGIES.each do |strategy|
            strategy.new(relation).execute
          end

          update_parents(relation)
        end
      end
    end

    private

    def update_parents(relation)
      parent_ids = parents_for(relation)
      return if parent_ids.blank?

      Epics::UpdateEpicsDatesWorker.perform_async(parent_ids)
    end

    # rubocop: disable CodeReuse/ActiveRecord -- complex update requires some query methods
    # rubocop: disable Database/AvoidUsingPluckWithoutLimit -- the query already uses the batch limited in 100 items
    def parents_for(relation)
      descendants = ::Gitlab::ObjectHierarchy.new(relation).descendants

      relation
        .has_parent
        .where.not(parent_id: descendants)
        .distinct
        .pluck(:parent_id)
    end
    # rubocop: enable CodeReuse/ActiveRecord
    # rubocop: enable Database/AvoidUsingPluckWithoutLimit
  end
end
