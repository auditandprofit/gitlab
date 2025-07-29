# frozen_string_literal: true

# rubocop:disable Gitlab/BoundedContexts -- TODO include branch rules bounded context
module BranchRules
  module ExternalStatusChecks
    class BaseService < BranchRules::BaseService
      def execute(skip_authorization: false)
        super
      rescue Gitlab::Access::AccessDeniedError
        ServiceResponse.error(
          message: "Failed to #{action_name} external status check",
          payload: { errors: ['Not allowed'] },
          reason: :access_denied
        )
      end

      private

      def action_name
        missing_method_error('action_name')
      end

      def authorized?
        can?(current_user, :update_branch_rule, branch_rule)
      end

      def execute_on_all_branches_rule
        ServiceResponse.error(
          message: 'All branch rules cannot configure external status checks',
          payload: { errors: ['All branch rules not allowed'] },
          reason: :unprocessable_entity
        )
      end

      def execute_on_all_protected_branches_rule
        ServiceResponse.error(
          message: 'All protected branch rules cannot configure external status checks',
          payload: { errors: ['All protected branches not allowed'] },
          reason: :unprocessable_entity
        )
      end
    end
  end
end
# rubocop:enable Gitlab/BoundedContexts
