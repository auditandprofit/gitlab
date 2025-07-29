# frozen_string_literal: true

module EE
  module BranchRules
    module BaseService
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      prepended do
        extend Forwardable

        def_delegators(:branch_rule, :approval_project_rules, :external_status_checks)
      end

      override :execute
      def execute(skip_authorization: false)
        raise ::Gitlab::Access::AccessDeniedError unless skip_authorization || authorized?

        case branch_rule
        when ::Projects::AllBranchesRule then return execute_on_all_branches_rule
        when ::Projects::AllProtectedBranchesRule then return execute_on_all_protected_branches_rule
        when ::Projects::BranchRule then return execute_on_branch_rule
        end

        ServiceResponse.error(message: 'Unknown branch rule type.')
      end

      def execute_on_all_branches_rule
        missing_method_error('execute_on_all_branches_rule')
      end

      def execute_on_all_protected_branches_rule
        missing_method_error('execute_on_all_protected_branches_rule')
      end
    end
  end
end
