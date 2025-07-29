# frozen_string_literal: true

module Subscriptions
  module Ai
    module DuoWorkflows
      class WorkflowEventsUpdated < BaseSubscription
        include Gitlab::Graphql::Laziness

        payload_type ::Types::Ai::DuoWorkflows::WorkflowEventType

        argument :workflow_id, Types::GlobalIDType[::Ai::DuoWorkflows::Workflow],
          required: true,
          description: 'Workflow ID to fetch duo workflow.'
        def authorized?(args)
          ::Gitlab::AppLogger.info(
            workflow_gid: args[:workflow_id],
            message: 'Starting subscription authorisation'
          )
          unauthorized! unless current_user

          workflow = force(GitlabSchema.find_by_gid(args[:workflow_id]))
          unless workflow && Ability.allowed?(current_user, :read_duo_workflow, workflow)
            msg = workflow ? 'workflow not found' : 'user can not read workflow'
            ::Gitlab::AppLogger.info(
              workflow_gid: args[:workflow_id],
              message: "Subscription unauthorized: #{msg}"
            )
            unauthorized!
          end

          ::Gitlab::AppLogger.info(
            workflow_gid: args[:workflow_id],
            message: 'Subscription authorised'
          )
          true
        end

        def update(args = {})
          ::Gitlab::AppLogger.info(
            workflow_gid: args[:workflow_id],
            message: 'Transmitting updates'
          )
          super
        end
      end
    end
  end
end
