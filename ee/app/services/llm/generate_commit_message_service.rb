# frozen_string_literal: true

module Llm
  class GenerateCommitMessageService < BaseService
    def valid?
      super &&
        Gitlab::Llm::StageCheck.available?(resource.resource_parent, :generate_commit_message) &&
        user.can?(:access_generate_commit_message, resource)
    end

    private

    def ai_action
      :generate_commit_message
    end

    def perform
      schedule_completion_worker
    end
  end
end
