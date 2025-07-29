# frozen_string_literal: true

# Model for join table between ApprovalGroupRule and ProtectedBranch
module ApprovalRules
  class ApprovalGroupRulesProtectedBranch < ApplicationRecord
    extend SuppressCompositePrimaryKeyWarning

    belongs_to :protected_branch
    belongs_to :approval_group_rule, class_name: 'ApprovalRules::ApprovalGroupRule'

    validates :protected_branch, :approval_group_rule, presence: true
  end
end
