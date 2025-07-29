# frozen_string_literal: true

module EE
  module BranchRules
    module UpdateService
      extend ::Gitlab::Utils::Override

      def execute_on_all_branches_rule
        ServiceResponse.error(message: 'All branches rules cannot be updated.')
      end

      def execute_on_all_protected_branches_rule
        ServiceResponse.error(message: 'All protected branches rules cannot be updated.')
      end

      override :permitted_params
      def permitted_params
        [
          :name,
          {
            branch_protection: [
              :allow_force_push,
              :code_owner_approval_required,
              {
                push_access_levels: %i[access_level deploy_key_id user_id group_id],
                merge_access_levels: %i[access_level user_id group_id]
              }
            ]
          }
        ]
      end
    end
  end
end
