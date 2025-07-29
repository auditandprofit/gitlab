# frozen_string_literal: true

module Resolvers
  module Ai
    module DuoWorkflows
      class WorkflowEventsResolver < BaseResolver
        include Gitlab::Graphql::Authorize::AuthorizeResource

        authorizes_object!

        type Types::Ai::DuoWorkflows::WorkflowEventType, null: false

        argument :workflow_id, Types::GlobalIDType[::Ai::DuoWorkflows::Workflow],
          required: true,
          description: 'Array of request IDs to fetch.'

        def resolve(**args)
          return [] unless current_user

          Gitlab::Graphql::Lazy.with_value(find_object(id: args[:workflow_id])) do |workflow|
            workflow && Ability.allowed?(current_user, :read_duo_workflow, workflow) ? workflow.checkpoints : []
          end
        end

        private

        def find_object(id:)
          GitlabSchema.find_by_gid(id)
        end
      end
    end
  end
end
