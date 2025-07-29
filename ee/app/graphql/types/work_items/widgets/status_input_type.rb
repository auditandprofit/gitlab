# frozen_string_literal: true

module Types
  module WorkItems
    module Widgets
      class StatusInputType < BaseInputObject
        graphql_name 'WorkItemWidgetStatusInput'

        argument :status, Types::GlobalIDType[::WorkItems::Statuses::Status],
          required: false,
          description: 'Global ID of the status.',
          prepare: ->(global_id, _) do
            return if global_id.nil?

            status = GitlabSchema.find_by_gid(global_id)
            status = status.sync if status.respond_to?(:sync)

            raise GraphQL::ExecutionError, "Status doesn't exist." if status.nil?

            status
          end
      end
    end
  end
end
