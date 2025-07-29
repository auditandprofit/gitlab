# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class GroupProtectedBranchesDeletionCheckService < BaseGroupService
      def execute
        group.all_security_orchestration_policy_configurations.any? do |config|
          config.active_scan_result_policies.any? { |policy| applies?(policy) }
        end
      end

      def applies?(policy)
        approval_settings = policy[:approval_settings] || (return false)

        return true if blocks_all_branch_modification?(approval_settings)

        case setting = approval_settings[:block_group_branch_modification]
        when true, false then setting
        when Hash then exceptions_permit_group?(setting)
        else false
        end
      end

      def blocks_all_branch_modification?(settings)
        # If `block_group_branch_modification` is absent and `block_branch_modification: true`,
        # we implicitly default to `block_group_branch_modification: true`
        settings[:block_branch_modification] && !settings.key?(:block_group_branch_modification)
      end

      def exceptions_permit_group?(setting)
        return false unless setting[:enabled]
        return true if setting[:exceptions].blank?

        setting[:exceptions].all? { |exception| exception[:id] != group.id }
      end
    end
  end
end
