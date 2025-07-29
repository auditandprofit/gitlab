# frozen_string_literal: true

module EE
  module Projects
    module ParticipantsService
      extend ::Gitlab::Utils::Override

      private

      override :project_members_relation
      def project_members_relation
        return super unless project.ai_review_merge_request_allowed?(current_user)

        super.union_with_user(::Users::Internal.duo_code_review_bot)
      end
    end
  end
end
