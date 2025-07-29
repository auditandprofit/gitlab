# frozen_string_literal: true

module Epics
  module SyncAsWorkItem
    extend ActiveSupport::Concern
    include ::Gitlab::Utils::StrongMemoize

    SyncAsWorkItemError = Class.new(StandardError)

    # Note: we do not need to sync `lock_version`.
    # https://gitlab.com/gitlab-org/gitlab/-/issues/439716
    ALLOWED_PARAMS = %i[
      iid title description confidential author_id created_at updated_at updated_by_id
      last_edited_by_id last_edited_at closed_by_id closed_at state_id external_key
      imported_from
    ].freeze

    def update_work_item_for!(epic)
      return true unless epic.work_item

      sync_color(epic, epic.work_item) if changed_attributes(epic).include?(:color)
      sync_dates_on_epic_update(epic, epic.work_item)
      epic.work_item.assign_attributes(update_params(epic))

      epic.work_item.save!(touch: false)
    rescue StandardError => error
      raise_error!(:update, error, epic)
    end

    private

    def update_params(epic)
      filtered_attributes = changed_attributes(epic)
        .intersection(ALLOWED_PARAMS + %i[title_html description_html])
        .index_with { |attr| epic[attr] }

      filtered_attributes.merge(
        { updated_by: epic.updated_by, updated_at: epic.updated_at, skip_description_version: true }
      )
    end

    def sync_color(epic, work_item)
      work_item_color = work_item.color || work_item.build_color

      # only set non default color or remove the color if default color is set to epic
      if epic.color.to_s == ::Epic::DEFAULT_COLOR.to_s && work_item.color.new_record?
        work_item.color = nil
      else
        work_item_color.color = epic.color
        work_item.color = work_item_color
      end
    end

    def sync_dates_on_epic_update(epic, work_item)
      changed_attributes = changed_date_attributes(epic)
      return if changed_attributes.blank?

      dates_source = work_item.dates_source || work_item.build_dates_source

      if changed_attributes.include?(:start_date_sourcing_epic_id)
        dates_source.start_date_sourcing_work_item_id = epic.start_date_sourcing_epic&.issue_id
        changed_attributes.delete(:start_date_sourcing_epic_id)
      end

      if changed_attributes.include?(:due_date_sourcing_epic_id)
        dates_source.due_date_sourcing_work_item_id = epic.due_date_sourcing_epic&.issue_id
        changed_attributes.delete(:due_date_sourcing_epic_id)
      end

      if changed_attributes.include?(:end_date)
        dates_source.due_date = epic.end_date
        changed_attributes.delete(:end_date)
      end

      dates_source.assign_attributes(changed_attributes.index_with { |attr| epic[attr] })

      work_item.dates_source = dates_source
    end

    def raise_error!(action, error, epic = nil)
      log_error(action, error.message, epic)

      Gitlab::ErrorTracking.track_and_raise_exception(error, epic_id: epic&.id)
    end

    def track_error(action, error_message, epic = nil)
      log_error(action, error_message, epic)

      Gitlab::ErrorTracking.track_exception(SyncAsWorkItemError.new(error_message), epic_id: epic&.id)
    end

    def log_error(action, error_message, epic)
      Gitlab::EpicWorkItemSync::Logger.error(
        message: "Not able to #{action} epic work item",
        error_message: error_message,
        group_id: group.id,
        epic_id: epic&.id)
    end

    def changed_date_attributes(epic)
      changed_attributes(epic).intersection(
        %i[
          start_date start_date_fixed start_date_is_fixed start_date_sourcing_milestone_id start_date_sourcing_epic_id
          end_date due_date_fixed due_date_is_fixed due_date_sourcing_milestone_id due_date_sourcing_epic_id
        ]
      )
    end

    def changed_attributes(epic)
      strong_memoize_with(:changed_attributes, epic) do
        epic.previous_changes.keys.map(&:to_sym)
      end
    end
  end
end
