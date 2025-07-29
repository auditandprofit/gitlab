# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class UpdateWorkflowStatusService
      def initialize(workflow:, status_event:, current_user:)
        @workflow = workflow
        @status_event = status_event
        @current_user = current_user
      end

      def execute
        return error_response("Can not update workflow", :not_found) unless feature_flag_enabled?

        unless @current_user.can?(:update_duo_workflow, @workflow)
          return error_response("Can not update workflow", :unauthorized)
        end

        handle_status_event
      end

      private

      def handle_status_event
        workflow_events = ::Ai::DuoWorkflows::Workflow.state_machines[:status].events.map { |event| event.name.to_s }
        unless workflow_events.include?(@status_event)
          return error_response("Can not update workflow status, unsupported event: #{@status_event}")
        end

        unless @workflow.status_events.include?(@status_event.to_sym)
          return error_response("Can not #{@status_event} workflow that has status #{@workflow.human_status_name}")
        end

        @workflow.fire_status_event(@status_event)

        GraphqlTriggers.workflow_events_updated(@workflow.checkpoints.last) if @workflow.checkpoints.any?

        ServiceResponse.success(payload: { workflow: @workflow }, message: "Workflow status updated")
      end

      def error_response(message, reason = :bad_request)
        ServiceResponse.error(message: message, reason: reason)
      end

      def feature_flag_enabled?
        if @workflow.chat?
          Feature.enabled?(:duo_agentic_chat, @current_user)
        else
          Feature.enabled?(:duo_workflow, @current_user)
        end
      end
    end
  end
end
