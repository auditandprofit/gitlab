# frozen_string_literal: true

module Mutations
  module BranchRules
    module ApprovalProjectRules
      class Create < BaseMutation
        graphql_name 'branchRuleApprovalProjectRuleCreate'

        authorize :update_branch_rule

        argument :branch_rule_id, ::Types::GlobalIDType[::Projects::BranchRule],
          required: true,
          description: 'Global ID of the branch rule to destroy.'

        argument :name, ::GraphQL::Types::String,
          required: true,
          description: 'Name of the approval rule.'

        argument :approvals_required, ::GraphQL::Types::Int,
          required: true,
          description: 'How many approvals are required to satify rule.'

        argument :user_ids, [::GraphQL::Types::ID],
          required: false,
          description: 'List of IDs of Users that can approval rule.'

        argument :group_ids, [::GraphQL::Types::ID],
          required: false,
          description: 'List of IDs of Groups that can approval rule.'

        field :approval_rule, ::Types::BranchRules::ApprovalProjectRuleType,
          null: true,
          description: 'Approval rule after mutation.'

        def resolve(branch_rule_id:, **params)
          branch_rule = authorized_find!(id: branch_rule_id)

          create_params = params.merge(
            skip_authorization: true,
            applies_to_all_protected_branches: branch_rule.instance_of?(::Projects::AllProtectedBranchesRule),
            protected_branch_ids: Array(branch_rule.protected_branch&.id)
          )

          result = ::ApprovalRules::CreateService.new(branch_rule.project, current_user, create_params).execute
          rule = result[:rule]

          {
            approval_rule: (rule if result.success?),
            errors: rule.errors.full_messages
          }
        end
      end
    end
  end
end
