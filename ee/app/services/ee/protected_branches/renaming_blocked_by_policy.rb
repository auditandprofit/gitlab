# frozen_string_literal: true

module EE
  module ProtectedBranches
    module RenamingBlockedByPolicy
      class RenameCheck < BasePolicyCheck
        def violated?
          renaming?(protected_branch) && blocked?(protected_branch)
        end

        private

        def renaming?(protected_branch)
          return false unless params[:name]

          protected_branch.name != params[:name]
        end

        def blocked?(protected_branch)
          return blocking_branch_modification?(protected_branch.project) if protected_branch.project_level?

          blocking_group_branch_modification?(protected_branch.group)
        end

        def blocking_branch_modification?(project)
          return false unless project&.licensed_feature_available?(:security_orchestration_policies)

          project.scan_result_policy_reads.blocking_branch_modification.exists?
        end

        def blocking_group_branch_modification?(group)
          return false unless group&.licensed_feature_available?(:security_orchestration_policies)

          ::Security::SecurityOrchestrationPolicies::GroupProtectedBranchesDeletionCheckService
            .new(group: group)
            .execute
        end
      end

      def execute(protected_branch, skip_authorization: false)
        RenameCheck.check!(protected_branch, params)

        super
      end
    end
  end
end
