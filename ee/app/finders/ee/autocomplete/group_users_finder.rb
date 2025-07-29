# frozen_string_literal: true

# This finder will return all the members as the FOSS version as well as
# the Duo Code Review bot if the current user has access to the Duo Code Review
# features
module EE
  module Autocomplete # rubocop:disable Gitlab/BoundedContexts -- FOSS finder is not bounded to a context
    module GroupUsersFinder
      extend ::Gitlab::Utils::Override

      override :execute
      def execute
        return super unless group.ai_review_merge_request_allowed?(current_user)

        super.union_with_user(::Users::Internal.duo_code_review_bot)
      end
    end
  end
end
