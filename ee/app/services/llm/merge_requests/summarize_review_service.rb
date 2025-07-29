# frozen_string_literal: true

module Llm
  module MergeRequests
    class SummarizeReviewService < ::Llm::BaseService
      private

      def perform
        schedule_completion_worker
      end

      def ai_action
        :summarize_review
      end

      def valid?
        super &&
          resource.to_ability_name == "merge_request" &&
          resource.draft_notes.authored_by(user).any? &&
          user.can?(:access_summarize_review, resource)
      end
    end
  end
end
