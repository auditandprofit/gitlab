# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class DestroyWorkflowService
      include ::Gitlab::Allowable

      def initialize(workflow:, current_user:)
        @workflow = workflow
        @current_user = current_user
      end

      def execute
        unless can?(current_user, :destroy_duo_workflow, workflow)
          return ::ServiceResponse.error(message: 'User not authorized to delete workflow')
        end

        if workflow.destroy
          ::ServiceResponse.success
        else
          ::ServiceResponse.error(message: workflow.errors.full_messages)
        end
      end

      private

      attr_reader :workflow, :current_user
    end
  end
end
