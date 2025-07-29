# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class WorkflowPolicy < BasePolicy
      condition(:can_use_agentic_chat) do
        can?(:access_duo_agentic_chat, @subject.resource_parent)
      end

      condition(:can_use_duo_workflows_in_project) do
        can?(:duo_workflow, @subject.project)
      end

      condition(:is_workflow_owner) do
        @subject.user == @user || @user.service_account?
      end

      condition(:can_update_workflow) do
        can?(:update_duo_workflow, @subject)
      end

      condition(:agentic_chat_workflow) do
        @subject.chat?
      end

      condition(:true_duo_workflow) do
        !@subject.chat?
      end

      condition(:duo_workflow_in_ci_available) do
        ::Feature.enabled?(:duo_workflow_in_ci, @user)
      end

      condition(:web_environment) do
        @subject.environment == "web"
      end

      rule { true_duo_workflow & can_use_duo_workflows_in_project & web_environment }.policy do
        enable :read_duo_workflow
      end

      rule { true_duo_workflow & can_use_duo_workflows_in_project & is_workflow_owner }.policy do
        enable :read_duo_workflow
        enable :update_duo_workflow
      end

      rule { agentic_chat_workflow & can_use_agentic_chat & is_workflow_owner }.policy do
        enable :read_duo_workflow
        enable :update_duo_workflow
      end

      rule { duo_workflow_in_ci_available & can_update_workflow }.policy do
        enable :execute_duo_workflow_in_ci
      end

      rule { is_workflow_owner }.enable :destroy_duo_workflow
    end
  end
end
