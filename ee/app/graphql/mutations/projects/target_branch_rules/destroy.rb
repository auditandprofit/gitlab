# frozen_string_literal: true

module Mutations
  module Projects
    module TargetBranchRules
      class Destroy < BaseMutation
        graphql_name 'ProjectTargetBranchRuleDestroy'

        authorize :admin_target_branch_rule

        argument :id, Types::GlobalIDType[::Projects::TargetBranchRule],
          required: true,
          description: "ID for the target branch rule."

        def resolve(id:)
          target_branch_rule = authorized_find!(id: id)

          result = ::TargetBranchRules::DestroyService
            .new(target_branch_rule.project, current_user, { id: target_branch_rule.id })
            .execute

          if result[:status] == :success
            {
              errors: []
            }
          else
            {
              errors: [result[:message]]
            }
          end
        end
      end
    end
  end
end
