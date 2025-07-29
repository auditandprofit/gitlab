# frozen_string_literal: true

module Types
  module WorkItems
    # rubocop:disable Graphql/AuthorizeTypes -- Authorized at the resolver level
    # rubocop:disable GraphQL/ExtractType -- Skip extraction
    class LifecycleType < BaseObject
      graphql_name 'WorkItemLifecycle'
      description 'Represents a lifecycle for work items'

      field :id, Types::GlobalIDType,
        experiment: { milestone: '18.1' },
        description: 'ID of the lifecycle.'

      field :name, GraphQL::Types::String,
        experiment: { milestone: '18.1' },
        description: 'Name of the lifecycle.'

      field :default_open_status, Types::WorkItems::StatusType,
        experiment: { milestone: '18.1' },
        description: 'Default open status of the lifecycle.'

      field :default_closed_status, Types::WorkItems::StatusType,
        experiment: { milestone: '18.1' },
        description: 'Default closed status of the lifecycle.'

      field :default_duplicate_status, Types::WorkItems::StatusType,
        experiment: { milestone: '18.1' },
        description: 'Default duplicate status of the lifecycle.'

      field :work_item_types, [Types::WorkItems::TypeType],
        experiment: { milestone: '18.1' },
        description: 'Work item types associated to the lifecycle.'

      field :statuses, [Types::WorkItems::StatusType],
        experiment: { milestone: '18.1' },
        description: 'All available statuses of the lifecycle.',
        method: :ordered_statuses
    end
    # rubocop:enable Graphql/AuthorizeTypes, GraphQL/ExtractType
  end
end
