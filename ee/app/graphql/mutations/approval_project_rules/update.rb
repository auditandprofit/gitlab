# frozen_string_literal: true

module Mutations
  module ApprovalProjectRules
    class Update < BaseMutation
      graphql_name 'approvalProjectRuleUpdate'

      authorize :edit_approval_rule

      argument :id, ::Types::GlobalIDType[::ApprovalProjectRule],
        required: true,
        description: 'Global ID of the approval rule to destroy.'

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

      def resolve(id:, **params)
        rule = authorized_find!(id: id)

        update_params = params.merge(skip_authorization: true)

        result = ::ApprovalRules::UpdateService.new(rule, current_user, update_params).execute

        {
          approval_rule: (rule if result.success?),
          errors: rule.errors.full_messages
        }
      end
    end
  end
end
