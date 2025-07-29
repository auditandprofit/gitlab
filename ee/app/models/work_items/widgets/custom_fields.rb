# frozen_string_literal: true

module WorkItems
  module Widgets
    class CustomFields < Base
      def custom_field_values(custom_field_ids: nil)
        active_fields = ::Issuables::CustomFieldsFinder.active_fields_for_work_item(work_item)
        active_fields = active_fields.id_in(custom_field_ids) if custom_field_ids.present?

        field_values = fetch_field_values(active_fields)

        active_fields.map do |field|
          value = if field.field_type_text? || field.field_type_number?
                    field_values[field.id]
                  elsif field.field_type_select?
                    field_values[field.id]&.sort_by(&:position)
                  end

          {
            custom_field: field,
            value: value
          }
        end
      end

      private

      def fetch_field_values(active_fields)
        fields_by_value_class = group_by_value_class(active_fields)

        field_values = fields_by_value_class.flat_map do |klass, fields|
          klass.for_field_and_work_item(fields.map(&:id), work_item.id)
        end

        field_values.each_with_object({}) do |field_value, values_by_field|
          if field_value.is_a?(SelectFieldValue)
            values_by_field[field_value.custom_field_id] ||= []
            values_by_field[field_value.custom_field_id] << field_value.custom_field_select_option
          else
            values_by_field[field_value.custom_field_id] = field_value.value
          end
        end
      end

      def group_by_value_class(active_fields)
        active_fields.group_by do |field|
          if field.field_type_text?
            TextFieldValue
          elsif field.field_type_number?
            NumberFieldValue
          elsif field.field_type_select?
            SelectFieldValue.includes(:custom_field_select_option)
          end
        end
      end
    end
  end
end
