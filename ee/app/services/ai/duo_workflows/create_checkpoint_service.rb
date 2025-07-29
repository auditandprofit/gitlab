# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class CreateCheckpointService
      include ::Services::ReturnServiceResponses

      def initialize(workflow:, params:)
        @params = params
        @workflow = workflow
      end

      def execute
        checkpoint = @workflow.checkpoints.new(checkpoint_attributes)

        return error(checkpoint.errors.full_messages, :bad_request) unless checkpoint.save

        GraphqlTriggers.workflow_events_updated(checkpoint)
        success(checkpoint: checkpoint)
      end

      def checkpoint_attributes
        @params.merge(workflow: @workflow)
      end
    end
  end
end
