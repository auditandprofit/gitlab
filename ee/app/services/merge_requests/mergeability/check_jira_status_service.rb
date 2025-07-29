# frozen_string_literal: true

module MergeRequests
  module Mergeability
    class CheckJiraStatusService < CheckBaseService
      identifier :jira_association_missing
      description 'Checks whether the title or description references a Jira issue.'

      def execute
        return inactive unless merge_request.project.prevent_merge_without_jira_issue?

        if merge_request.has_jira_issue_keys?
          success
        else
          failure(reason: identifier)
        end
      end

      def skip?
        params[:skip_jira_check].present?
      end

      def cacheable?
        false
      end
    end
  end
end
