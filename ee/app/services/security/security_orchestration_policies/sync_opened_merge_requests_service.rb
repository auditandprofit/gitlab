# frozen_string_literal: true

# This class will be removed with https://gitlab.com/gitlab-org/gitlab/-/issues/504296
module Security
  module SecurityOrchestrationPolicies
    class SyncOpenedMergeRequestsService < BaseMergeRequestsService
      def initialize(project:, policy_configuration:)
        super(project: project)

        @policy_configuration = policy_configuration
      end

      def execute
        measure(HISTOGRAM, callback: ->(duration) { log_duration(duration) }) do
          each_open_merge_request do |merge_request|
            merge_request.delete_approval_rules_for_policy_configuration(policy_configuration.id)
            merge_request.sync_project_approval_rules_for_policy_configuration(policy_configuration.id)

            sync_merge_request(merge_request)
          end
        end
      end

      private

      attr_reader :policy_configuration
    end
  end
end
