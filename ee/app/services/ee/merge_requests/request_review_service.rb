# frozen_string_literal: true

module EE
  module MergeRequests
    module RequestReviewService
      extend ::Gitlab::Utils::Override

      override :with_valid_reviewer
      def with_valid_reviewer(merge_request, user)
        if user == duo_code_review_bot && !merge_request.ai_review_merge_request_allowed?(current_user)

          return error(
            s_("DuoCodeReview|Your account doesn't have GitLab Duo access. " \
              "Please contact your system administrator for access.")
          )
        end

        super
      end
    end
  end
end
