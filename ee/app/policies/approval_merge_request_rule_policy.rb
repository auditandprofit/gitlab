# frozen_string_literal: true

class ApprovalMergeRequestRulePolicy < BasePolicy
  delegate { @subject.merge_request }

  condition(:editable) do
    if !@subject.user_defined?
      false
    elsif ::Feature.enabled?(:ensure_consistent_editing_rule, @subject.merge_request.project)
      can?(:update_approvers, @subject.merge_request)
    else
      can?(:update_merge_request, @subject.merge_request)
    end
  end

  rule { can?(:read_merge_request) }.enable :read_approval_rule
  rule { editable }.enable :edit_approval_rule
end
