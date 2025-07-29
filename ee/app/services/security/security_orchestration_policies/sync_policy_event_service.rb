# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class SyncPolicyEventService < BaseProjectPolicyService
      def initialize(project:, security_policy:, event:)
        super(project: project, security_policy: security_policy)
        @event = event
      end

      def execute
        case event
        when Projects::ComplianceFrameworkChangedEvent
          sync_policy_for_compliance_framework(event)
        when ::Repositories::ProtectedBranchCreatedEvent, ::Repositories::ProtectedBranchDestroyedEvent
          sync_policy_for_protected_branch(event)
        when ::Repositories::DefaultBranchChangedEvent
          sync_all_rules
        when Security::PolicyResyncEvent
          resync_policy
        end
      end

      private

      def resync_policy
        unlink_policy
        link_policy
      end

      def sync_all_rules
        sync_project_approval_policy_rules_service.update_rules(security_policy.approval_policy_rules.undeleted)
      end

      def sync_policy_for_compliance_framework(event)
        return unless security_policy.scope_has_framework?(event.data[:compliance_framework_id])

        if event.data[:event_type] == Projects::ComplianceFrameworkChangedEvent::EVENT_TYPES[:added]
          link_policy
        else
          unlink_policy
        end
      end

      def sync_policy_for_protected_branch(event)
        rules = affected_rules(event.data[:protected_branch_id])
        return if rules.empty?

        sync_project_approval_policy_rules_service.update_rules(rules)
      end

      def affected_rules(protected_branch_id)
        rules = security_policy.approval_policy_rules.undeleted
        return rules if protected_branch_id.nil?

        rules.select do |approval_policy_rule|
          branch_ids = sync_project_approval_policy_rules_service.protected_branch_ids(approval_policy_rule)
          branch_ids.include?(protected_branch_id)
        end
      end

      attr_reader :event
    end
  end
end
