# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class SyncMergeRequestsService < BaseMergeRequestsService
      def initialize(project:, security_policy:)
        super(project: project)

        @security_policy = security_policy
      end

      def execute
        measure(HISTOGRAM, callback: ->(duration) { log_duration(duration) }) do
          each_open_merge_request do |merge_request|
            merge_request.sync_project_approval_rules_for_approval_policy_rules(
              security_policy.approval_policy_rules.undeleted
            )

            sync_merge_request(merge_request)
          end
        end
      end

      private

      attr_reader :security_policy

      def policy_configuration
        security_policy.security_orchestration_policy_configuration
      end
    end
  end
end
