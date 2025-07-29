# frozen_string_literal: true

module EE
  module Types
    module WorkItems
      module NegatedWorkItemFilterInputType
        extend ActiveSupport::Concern

        prepended do
          argument :health_status_filter, [::Types::HealthStatusEnum],
            required: false,
            description: 'Health status not applied to the work items.
                    Includes work items where health status is not set.'
          argument :weight, GraphQL::Types::String,
            required: false,
            description: 'Weight not applied to the work items.'
          argument :iteration_id, [::GraphQL::Types::ID],
            required: false,
            description: 'List of iteration Global IDs not applied to the work items.'
        end
      end
    end
  end
end
