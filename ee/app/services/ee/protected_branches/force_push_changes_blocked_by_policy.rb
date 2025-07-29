# frozen_string_literal: true

module EE
  module ProtectedBranches # rubocop:disable Gitlab/BoundedContexts -- TODO: Namespacing
    module ForcePushChangesBlockedByPolicy
      class ForcePushCheck < BasePolicyCheck
        def violated?
          forbidden_params?(protected_branch) && blocked?(protected_branch)
        end

        private

        def forbidden_params?(protected_branch)
          alters_allow_force_push?(protected_branch) || alters_push_access_levels?
        end

        def alters_allow_force_push?(protected_branch)
          return false unless params.key?(:allow_force_push)

          protected_branch.allow_force_push != params[:allow_force_push]
        end

        def alters_push_access_levels?
          params[:push_access_levels_attributes]&.any?
        end

        def blocked?(protected_branch)
          return false unless protected_branch.project_level?

          protected_branch
            .project
            .scan_result_policy_reads
            .prevent_pushing_and_force_pushing
            .exists?
        end
      end

      def execute(protected_branch, skip_authorization: false)
        ForcePushCheck.check!(protected_branch, params)

        super
      end
    end
  end
end
