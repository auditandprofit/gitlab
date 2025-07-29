# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class BaseMergeRequestsService
      include Gitlab::Loggable

      HISTOGRAM = :gitlab_security_policies_sync_opened_merge_requests_duration_seconds

      def initialize(project:)
        @project = project
      end

      def each_open_merge_request
        related_merge_requests.each_batch do |mr_batch|
          mr_batch.each do |merge_request|
            yield merge_request
          end
        end
      end

      private

      attr_reader :project

      def sync_merge_request(merge_request)
        sync_any_merge_request_approval_rules(merge_request)
        sync_preexisting_state_approval_rules(merge_request)
        notify_for_policy_violations(merge_request)

        head_pipeline = merge_request.diff_head_pipeline
        unless head_pipeline
          return ::Security::ScanResultPolicies::UnblockFailOpenApprovalRulesWorker.perform_async(merge_request.id)
        end

        ::Security::ScanResultPolicies::SyncFindingsToApprovalRulesWorker.perform_async(head_pipeline.id)
        ::Ci::SyncReportsToReportApprovalRulesWorker.perform_async(head_pipeline.id)
      end

      def sync_any_merge_request_approval_rules(merge_request)
        return if merge_request.project.scan_result_policy_reads.targeting_commits.none?

        ::Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker.perform_async(merge_request.id)
      end

      def sync_preexisting_state_approval_rules(merge_request)
        return unless merge_request.approval_rules.by_report_types([:scan_finding, :license_scanning]).any?

        ::Security::ScanResultPolicies::SyncPreexistingStatesApprovalRulesWorker.perform_async(merge_request.id)
      end

      def notify_for_policy_violations(merge_request)
        ::Security::UnenforceablePolicyRulesNotificationWorker.perform_async(
          merge_request.id,
          { 'force_without_approval_rules' => true }
        )
      end

      def log_duration(duration)
        Gitlab::AppJsonLogger.debug(
          build_structured_payload(
            duration: duration,
            configuration_id: policy_configuration.id,
            project_id: project.id))
      end

      delegate :measure, to: ::Security::SecurityOrchestrationPolicies::ObserveHistogramsService

      def related_merge_requests
        project.merge_requests.opened
      end
    end
  end
end
