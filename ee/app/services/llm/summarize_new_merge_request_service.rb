# frozen_string_literal: true

module Llm
  class SummarizeNewMergeRequestService < ::Llm::BaseService
    def valid?
      super &&
        resource.is_a?(Project) &&
        user.can?(:access_summarize_new_merge_request, resource)
    end

    private

    def ai_action
      :summarize_new_merge_request
    end

    def perform
      schedule_completion_worker
    end
  end
end
