# frozen_string_literal: true

module EE
  module MergeRequests
    module UpdateService
      include ::MergeRequests::ApprovalRulesAttributeMapping
      extend ::Gitlab::Utils::Override

      override :handle_changes
      def handle_changes(merge_request, options)
        handle_draft_state_change(merge_request, merge_request.previous_changes)

        super

        handle_override_requested_changes(merge_request, merge_request.previous_changes)
      end

      private

      override :general_fallback
      def general_fallback(merge_request)
        if ::Feature.enabled?(:v2_approval_rules, merge_request.project)
          add_v2_approval_rules_attributes
          update_v1_approval_rule_ids(merge_request)
        end

        if merge_request.merged?
          params.delete(:reset_approval_rules_to_defaults)
          params.delete(:approval_rules_attributes)
        end

        reset_approval_rules(merge_request) if params.delete(:reset_approval_rules_to_defaults)

        merge_request = super(merge_request)

        merge_request.reset_approval_cache!

        return merge_request if update_task_event?

        ::MergeRequests::UpdateBlocksService
          .new(merge_request, current_user, blocking_merge_requests_params)
          .execute

        merge_request
      end

      override :after_update
      def after_update(merge_request, old_associations)
        super

        merge_request.run_after_commit do
          ::MergeRequests::SyncCodeOwnerApprovalRulesWorker.perform_async(merge_request.id)
        end

        event = ::MergeRequests::UpdatedEvent.new(data: { merge_request_id: merge_request.id })
        merge_request.run_after_commit_or_now do
          ::Gitlab::EventStore.publish(event)
        end
      end

      override :delete_approvals_on_target_branch_change
      def delete_approvals_on_target_branch_change(merge_request)
        delete_approvals(merge_request) if reset_approvals?(merge_request, nil)
        schedule_policy_synchronization(merge_request)
        sync_any_merge_request_approval_rules(merge_request)
        notify_for_policy_violations(merge_request)
        audit_security_policy_branch_bypass(merge_request)
      end

      def reset_approval_rules(merge_request)
        return unless merge_request.project.can_override_approvers?

        merge_request.approval_rules.regular_or_any_approver.delete_all
      end

      def schedule_policy_synchronization(merge_request)
        if ::Feature.disabled?(:merge_request_approval_policies_inapplicable_rule_evaluation, merge_request.project)
          return
        end

        merge_request.synchronize_approval_rules_from_target_project
        merge_request.schedule_policy_synchronization
      end

      def sync_any_merge_request_approval_rules(merge_request)
        # `MergeRequest#schedule_policy_synchronization` enqueues `SyncAnyMergeRequestApprovalRulesWorker` already
        if ::Feature.enabled?(:merge_request_approval_policies_inapplicable_rule_evaluation, merge_request.project)
          return
        end

        return if merge_request.project.scan_result_policy_reads.targeting_commits.none?

        ::Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker.perform_async(merge_request.id)
      end

      def notify_for_policy_violations(merge_request)
        ::Security::SyncPolicyViolationCommentWorker.perform_async(merge_request.id)
      end

      def handle_override_requested_changes(merge_request, changed_fields)
        return unless changed_fields.include?('override_requested_changes')

        override_requested_changes = changed_fields['override_requested_changes']

        ::SystemNoteService.override_requested_changes(merge_request, current_user, override_requested_changes.last)
        trigger_merge_request_status_updated(merge_request)

        ::Gitlab::EventStore.publish(
          ::MergeRequests::OverrideRequestedChangesStateEvent.new(
            data: { current_user_id: current_user.id, merge_request_id: merge_request.id }
          )
        )
      end

      def should_publish_update_event?(merge_request, changed_fields)
        super || merge_request.has_jira_issue_keys?
      end

      def handle_draft_state_change(merge_request, changed_fields)
        return unless changed_fields.include?('title')

        old_title, new_title = changed_fields['title']

        return unless ::MergeRequest.draft?(old_title) && !::MergeRequest.draft?(new_title)

        assign_duo_as_reviewer(merge_request)
      end
    end
  end
end
