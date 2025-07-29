# frozen_string_literal: true

module Types
  module WorkItems
    module Widgets
      # Disabling widget level authorization as it might be too granular
      # and we already authorize the parent work item
      # rubocop:disable Graphql/AuthorizeTypes -- reason above
      class StatusType < BaseObject
        graphql_name 'WorkItemWidgetStatus'
        description 'Represents status widget'

        implements ::Types::WorkItems::WidgetInterface

        field :status, Types::WorkItems::StatusType,
          null: true,
          experiment: { milestone: '17.11' },
          description: 'Status assigned to work item.',
          resolver: Resolvers::WorkItems::Statuses::StatusResolver
      end
      # rubocop:enable Graphql/AuthorizeTypes
    end
  end
end
