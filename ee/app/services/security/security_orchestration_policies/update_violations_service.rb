# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class UpdateViolationsService
      include ::Gitlab::Utils::StrongMemoize

      attr_reader :merge_request, :violated_policies, :unviolated_policies, :skipped_policies, :violation_data

      delegate :project, to: :merge_request

      def initialize(merge_request)
        @merge_request = merge_request
        @violated_policies = Set.new
        @unviolated_policies = Set.new
        @skipped_policies = Set.new
        @violation_data = {}
      end

      def add(violated, unviolated)
        violated_policies.merge(violated.compact)
        unviolated_policies.merge(unviolated.compact)
      end

      def add_violation(policy, report_type, data, context: nil)
        add([policy], [])

        @violation_data[policy.id] ||= {}
        @violation_data[policy.id].deep_merge!({ context: context, violations: { report_type => data } }.compact_blank)
      end

      def remove_violation(policy)
        unviolated_policies.add(policy)
      end

      def add_error(policy, error, context: nil, **extra_data)
        add([policy], [])

        violation_data[policy.id] ||= {}
        violation_data[policy.id][:errors] ||= []
        violation_data[policy.id][:errors] << {
          error: Security::ScanResultPolicyViolation::ERRORS[error],
          **extra_data
        }
        violation_data[policy.id].deep_merge!({ context: context }) if context.present?
      end

      def skip(policy)
        skipped_policies.add(policy)

        violation_data[policy.id] ||= {}
        violation_data[policy.id][:errors] ||= []
        violation_data[policy.id][:errors] << {
          error: Security::ScanResultPolicyViolation::ERRORS[:evaluation_skipped]
        }
      end

      def execute
        Security::ScanResultPolicyViolation.transaction do
          delete_violations if unviolated_policies.any?
          create_violations if violated_policies.any? || skipped_policies.any?
        end

        publish_violations_updated_event if publish_event?
        record_violations_detected_audit_event if record_violations_detected_audit_event?
        record_violations_resolved_audit_event if record_violations_resolved_audit_event?

        [violated_policies.clear, unviolated_policies.clear, skipped_policies.clear]
      end

      private

      def publish_event?
        unviolated_policies.any? || violated_policies.any? || skipped_policies.any?
      end

      # rubocop: disable CodeReuse/ActiveRecord, Database/AvoidUsingPluckWithoutLimit -- unviolated_policies is a Set
      def delete_violations
        violations = Security::ScanResultPolicyViolation
          .where(merge_request_id: merge_request.id, scan_result_policy_id: unviolated_policies.pluck(:id))

        @deleted_violations_with_data = violations.with_violation_data.exists?

        violations.each_batch do |batch|
          batch.delete_all
        end
      end
      # rubocop: enable CodeReuse/ActiveRecord, Database/AvoidUsingPluckWithoutLimit

      def create_violations
        # If the same policy is marked as both skipped and failed, it's persisted as failed
        attrs = violated_policies.map { |policy| policy_to_violation(policy, :failed) } +
          (skipped_policies - violated_policies).map { |policy| policy_to_violation(policy, :skipped) }
        return unless attrs.any?

        Security::ScanResultPolicyViolation.upsert_all(attrs, unique_by: %w[scan_result_policy_id merge_request_id])
      end

      def policy_to_violation(policy, default_status)
        {
          scan_result_policy_id: policy.id,
          approval_policy_rule_id: policy.approval_policy_rule&.id,
          merge_request_id: merge_request.id,
          project_id: merge_request.project_id,
          violation_data: violation_data[policy.id],
          status: violation_status_for_policy(policy, default_status)
        }
      end

      # We only warn for errored fail-open policies, in other cases (when we have actual `violations`), we should fail.
      def violation_status_for_policy(policy, default_status)
        policy.fail_open? && !violation_data[policy.id]&.key?(:violations) ? :warn : default_status
      end

      def publish_violations_updated_event
        ::Gitlab::EventStore.publish(
          ::MergeRequests::ViolationsUpdatedEvent.new(
            data: { merge_request_id: merge_request.id }
          )
        )
      end

      def record_violations_detected_audit_event?
        return false unless ::Feature.enabled?(
          :collect_security_policy_violations_detected_audit_events, merge_request.project
        )

        updated_violations.any? && updated_violations.running.empty?
      end

      def record_violations_detected_audit_event
        ::MergeRequests::PolicyViolationsDetectedAuditEventWorker.perform_async(merge_request.id)
      end

      def updated_violations
        merge_request.scan_result_policy_violations
      end
      strong_memoize_attr :updated_violations

      def record_violations_resolved_audit_event?
        return unless ::Feature.enabled?(
          :collect_security_policy_violations_resolved_audit_events, merge_request.project
        )

        @deleted_violations_with_data && updated_violations.empty?
      end

      def record_violations_resolved_audit_event
        ::MergeRequests::PolicyViolationsResolvedAuditEventWorker.perform_async(merge_request.id)
      end
    end
  end
end
