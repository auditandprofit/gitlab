# frozen_string_literal: true

module EE
  module MergeRequests
    module RefreshService
      extend ::Gitlab::Utils::Override

      private

      override :refresh_merge_requests!
      def refresh_merge_requests!
        check_merge_train_status

        super

        remove_requested_changes
        update_approvers_for_source_branch_merge_requests
        update_approvers_for_target_branch_merge_requests

        reset_approvals_for_merge_requests(push.ref, push.newrev)

        trigger_suggested_reviewers_fetch
        sync_any_merge_request_approval_rules
        sync_preexisting_states_approval_rules
        sync_unenforceable_approval_rules
      end

      def trigger_suggested_reviewers_fetch
        return unless project.can_suggest_reviewers?

        merge_requests_for_source_branch.each do |mr|
          next unless mr.can_suggest_reviewers?

          ::MergeRequests::FetchSuggestedReviewersWorker.perform_async(mr.id)
        end
      end

      def reset_approvals_for_merge_requests(ref, newrev)
        # Add a flag that prevents unverified changes from getting through in the
        #   10 second window below
        #
        merge_requests_for(push.branch_name, mr_states: [:opened, :closed]).each do |mr|
          if reset_approvals?(mr, newrev)
            mr.approval_state.temporarily_unapprove!
          end
        end

        # We need to make sure the code owner approval rules have all been synced
        #   first, so we delay for 10s. We are trying to pin down and fix the race
        #   condition: https://gitlab.com/gitlab-org/gitlab/-/issues/373846
        #
        MergeRequestResetApprovalsWorker.perform_in(10.seconds, project.id, current_user.id, ref, newrev)
      end

      def update_approvers_for_source_branch_merge_requests
        merge_requests_for_source_branch.each do |merge_request|
          ::MergeRequests::SyncCodeOwnerApprovalRules.new(merge_request).execute if project.feature_available?(:code_owners)
          ::MergeRequests::SyncReportApproverApprovalRules.new(merge_request, current_user).execute
        end
      end

      def update_approvers_for_target_branch_merge_requests
        if project.feature_available?(:code_owners) && branch_protected? && code_owners_updated?
          merge_requests_for_target_branch.each do |merge_request|
            ::MergeRequests::SyncCodeOwnerApprovalRules.new(merge_request).execute unless merge_request.on_train?
          end
        end
      end

      def sync_any_merge_request_approval_rules
        return if project.scan_result_policy_reads.targeting_commits.none?

        merge_requests_for_source_branch.each do |merge_request|
          ::Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker.perform_async(merge_request.id)
        end
      end

      def sync_preexisting_states_approval_rules
        merge_requests_for_source_branch.each do |merge_request|
          if merge_request.approval_rules.by_report_types([:scan_finding, :license_scanning]).any?
            ::Security::ScanResultPolicies::SyncPreexistingStatesApprovalRulesWorker.perform_async(merge_request.id)
          end
        end
      end

      def sync_unenforceable_approval_rules
        merge_requests_for_source_branch.each do |merge_request|
          unless merge_request.head_pipeline_id
            ::Security::UnenforceablePolicyRulesNotificationWorker.perform_async(merge_request.id)
          end
        end
      end

      def branch_protected?
        project.branch_requires_code_owner_approval?(push.branch_name)
      end

      def code_owners_updated?
        return unless push.branch_updated?

        push.modified_paths.find { |path| ::Gitlab::CodeOwners::FILE_PATHS.include?(path) }
      end

      def reset_approvals?(merge_request, newrev)
        !merge_request.merge_train_car && super
      end

      override :abort_auto_merges?
      def abort_auto_merges?(merge_request)
        return true if merge_request.merge_train_car

        super
      end

      # rubocop:disable Gitlab/ModuleWithInstanceVariables
      def check_merge_train_status
        return unless @push.branch_updated?

        MergeTrains::CheckStatusService.new(project, current_user)
          .execute(project, @push.branch_name, @push.newrev)
      end

      def merge_requests_for_target_branch(reload: false, mr_states: [:opened])
        @target_merge_requests = nil if reload
        @target_merge_requests ||= project.merge_requests
          .with_state(mr_states)
          .by_target_branch(push.branch_name)
          .including_merge_train
      end
      # rubocop:enable Gitlab/ModuleWithInstanceVariables

      def remove_requested_changes
        return unless project.feature_available?(:requested_changes_block_merge_request)

        update_reviewer_service = ::MergeRequests::UpdateReviewerStateService
          .new(project: project, current_user: current_user)

        merge_requests_for_source_branch
          .select(&:merge_requests_disable_committers_approval?)
          .each do |merge_request|
            merge_request.destroy_requested_changes(current_user)
            update_reviewer_service.execute(merge_request, 'unreviewed')
          end
      end

      override :schedule_duo_code_review
      def schedule_duo_code_review(merge_request)
        return unless merge_request.project.auto_duo_code_review_enabled
        return if merge_request.draft?

        previous_diff = merge_request.previous_diff

        return unless previous_diff && previous_diff.empty?
        return unless merge_request.reviewers.duo_code_review_bot.any?

        request_duo_code_review(merge_request)
      end
    end
  end
end
