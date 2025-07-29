# frozen_string_literal: true

module EE
  module Projects
    module BranchRules
      module SquashOptions
        module UpdateService
          extend ::Gitlab::Utils::Override

          override :execute_on_branch_rule
          def execute_on_branch_rule
            return super unless project.licensed_feature_available?(:branch_rule_squash_options)

            ::ProtectedBranches::UpdateService.new(project, current_user, {
              squash_option_attributes: {
                protected_branch: protected_branch,
                project: project,
                squash_option: squash_option
              }
            }).execute(protected_branch)

            return ServiceResponse.error(message: protected_branch.errors.full_messages) if protected_branch.errors.any?

            success_response
          end
        end
      end
    end
  end
end
