# frozen_string_literal: true

module Types
  module WorkItems
    module Widgets
      class CustomFieldFilterInputType < BaseInputObject
        graphql_name 'WorkItemWidgetCustomFieldFilterInputType'

        argument :custom_field_id, ::Types::GlobalIDType[::Issuables::CustomField],
          required: true,
          description: copy_field_description(Types::Issuables::CustomFieldType, :id),
          prepare: ->(id, _ctx) { id&.model_id }

        argument :selected_option_ids, [::Types::GlobalIDType[::Issuables::CustomFieldSelectOption]],
          required: false,
          description: 'Global IDs of the selected options for custom fields with select type.',
          prepare: ->(ids, _ctx) { ids.map(&:model_id) }

        def prepare
          { custom_field_id => selected_option_ids }
        end
      end
    end
  end
end
