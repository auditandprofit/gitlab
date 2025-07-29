# frozen_string_literal: true

module Mutations
  module Projects
    module BranchRules
      module SquashOptions
        class Delete < BaseMutation
          graphql_name 'BranchRuleSquashOptionDelete'
          description 'Delete a squash option for a branch rule'

          authorize :update_branch_rule
          argument :branch_rule_id, ::Types::GlobalIDType[::Projects::BranchRule],
            required: true,
            description: 'Global ID of the branch rule.'

          def resolve(branch_rule_id:)
            branch_rule = authorized_find!(id: branch_rule_id)

            if feature_disabled?(branch_rule.project)
              raise_resource_not_available_error! 'Squash options feature disabled'
            end

            service_response = ::Projects::BranchRules::SquashOptions::DestroyService.new(
              branch_rule,
              current_user: current_user
            ).execute

            {
              errors: service_response.errors
            }
          end

          private

          def feature_disabled?(project)
            !project.licensed_feature_available?(:branch_rule_squash_options)
          end
        end
      end
    end
  end
end
