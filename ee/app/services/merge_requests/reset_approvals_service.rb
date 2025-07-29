# frozen_string_literal: true

module MergeRequests
  class ResetApprovalsService < ::MergeRequests::BaseService
    def execute(ref, newrev, skip_reset_checks: false)
      reset_approvals_for_merge_requests(ref, newrev, skip_reset_checks)
    end

    private

    # Note: Closed merge requests also need approvals reset.
    def reset_approvals_for_merge_requests(ref, newrev, skip_reset_checks = false)
      branch_name = ::Gitlab::Git.ref_name(ref)
      merge_requests = merge_requests_for(branch_name, mr_states: [:opened, :closed])

      merge_requests.each do |merge_request|
        mr_patch_id_sha = merge_request.current_patch_id_sha

        if skip_reset_checks
          # Delete approvals immediately, with no additional checks or side-effects
          #
          delete_approvals(merge_request, patch_id_sha: mr_patch_id_sha, cause: :new_push)
        else
          reset_approvals(merge_request, newrev, patch_id_sha: mr_patch_id_sha)
        end

        # Note: When we remove the 10 second delay in
        # ee/app/services/ee/merge_requests/refresh_service.rb :51
        # We should be able to remove this
        AutoMergeProcessWorker.perform_async(merge_request.id) if merge_request.auto_merge_enabled?
      end
    end

    def reset_approvals(merge_request, newrev = nil, patch_id_sha: nil, cause: :new_push)
      return unless reset_approvals?(merge_request, newrev)

      if delete_approvals?(merge_request)
        delete_approvals(merge_request, patch_id_sha: patch_id_sha, cause: cause)
      elsif merge_request.target_project.project_setting.selective_code_owner_removals
        delete_code_owner_approvals(merge_request, patch_id_sha: patch_id_sha, cause: cause)
      end
    end

    def delete_code_owner_approvals(merge_request, patch_id_sha: nil, cause: nil)
      return if merge_request.approvals.empty?

      code_owner_rules = approved_code_owner_rules(merge_request)
      return if code_owner_rules.empty?

      previous_diff_head_sha = merge_request.previous_diff&.head_commit_sha

      rule_names = ::Gitlab::CodeOwners.entries_since_merge_request_commit(merge_request,
        sha: previous_diff_head_sha).map(&:pattern)
      match_ids = code_owner_rules.flat_map do |rule|
        next unless rule_names.include?(rule.name)

        rule.approved_approvers.map(&:id)
      end.compact

      # In case there is still a temporary flag on the MR
      #
      merge_request.approval_state.expire_unapproved_key!

      filtered_approvals = merge_request.approvals.where(user_id: match_ids) # rubocop:disable CodeReuse/ActiveRecord
      filtered_approvals = filter_approvals(filtered_approvals, patch_id_sha) if patch_id_sha.present?
      approver_ids = filtered_approvals.map(&:user_id)

      filtered_approvals.delete_all

      merge_request.batch_update_reviewer_state(approver_ids, 'unapproved')

      trigger_merge_request_merge_status_updated(merge_request)
      trigger_merge_request_approval_state_updated(merge_request)
      publish_approvals_reset_event(merge_request, cause, approver_ids)
    end

    def approved_code_owner_rules(merge_request)
      merge_request.wrapped_approval_rules.select { |rule| rule.code_owner? && rule.approved_approvers.any? }
    end
  end
end
