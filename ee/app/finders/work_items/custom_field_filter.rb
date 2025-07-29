# frozen_string_literal: true

module WorkItems
  class CustomFieldFilter < ::Issuables::BaseFilter
    def initialize(work_item_id_column: :id, **kwargs)
      @work_item_id_column = work_item_id_column

      super(**kwargs)
    end

    def filter(issuables)
      return issuables if params[:custom_field].blank?
      return issuables if parent && !parent.licensed_feature_available?(:custom_fields)

      filter_select_fields(issuables, params[:custom_field])
    end

    private

    # select field filter params are in the format:
    # { <custom_field_id> => [<select_option_id>, ...] }
    def filter_select_fields(issuables, select_params)
      # transform the params to individual (custom_field_id, select_option_id) pairs
      custom_field_and_option_ids = select_params.to_h.flat_map do |custom_field_id, select_option_ids|
        [custom_field_id].product(Array(select_option_ids))
      end

      # rubocop: disable CodeReuse/ActiveRecord -- Used only for this filter
      custom_field_and_option_ids.inject(issuables) do |issuables, (custom_field_id, select_option_id)|
        issuables.where_exists(
          WorkItems::SelectFieldValue.where(
            custom_field_id: custom_field_id,
            custom_field_select_option_id: select_option_id
          ).where(
            WorkItems::SelectFieldValue.arel_table[:work_item_id].eq(issuables.arel_table[@work_item_id_column])
          )
        )
      end
      # rubocop: enable CodeReuse/ActiveRecord
    end
  end
end
