# frozen_string_literal: true

module ApprovalRules
  class ApprovalGroupRulePolicy < BasePolicy
    delegate { @subject.group }

    condition(:editable) do
      can?(:update_approval_rule, @subject.group)
    end

    rule { editable }.enable :edit_group_approval_rule

    condition(:readable) do
      can?(:read_group, @subject.group)
    end

    rule { readable }.enable :read_group_approval_rule
  end
end
