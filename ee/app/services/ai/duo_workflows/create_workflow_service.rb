# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class CreateWorkflowService
      include ::Services::ReturnServiceResponses

      def initialize(container:, current_user:, params:)
        @container = container
        @current_user = current_user
        @params = params
      end

      def execute
        unless @container.is_a?(::Project) || @container.is_a?(::Namespace)
          return error('container must be a Project or Namespace', :bad_request)
        end

        response = check_access
        return response if response&.error?

        workflow = Ai::DuoWorkflows::Workflow.new(workflow_attributes)

        return error(workflow.errors.full_messages, :bad_request) unless workflow.save

        success(workflow: workflow)
      end

      def workflow_attributes
        @params.merge(
          user: @current_user,
          **container_attributes
        )
      end

      private

      def check_access
        if workflow_definition == 'chat' || workflow_definition == :chat
          check_agentic_chat_access
        else
          check_duo_workflow_access
        end
      end

      def check_agentic_chat_access
        return if Ability.allowed?(@current_user, :access_duo_agentic_chat, @container)

        error('forbidden to access agentic chat', :forbidden)
      end

      def check_duo_workflow_access
        return if Ability.allowed?(@current_user, :duo_workflow, @container)

        error('forbidden to access duo workflow', :forbidden)
      end

      def workflow_definition
        @params['workflow_definition'] || @params[:workflow_definition]
      end

      def container_attributes
        if @container.is_a?(::Project)
          { project: @container }
        elsif @container.is_a?(::Namespace)
          { namespace: @container }
        end
      end
    end
  end
end
