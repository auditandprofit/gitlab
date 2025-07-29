# frozen_string_literal: true

module Projects
  class AllBranchesRulePolicy < ::Projects::BranchRulePolicy
    # These conditions override ones set in EE::ProtectedBranchPolicy as
    # Projects::AllBranchesRule objects do not have a ProtectedBranch
    # associated with them
    condition(:unprotect_restrictions_enabled) { false }
    condition(:can_maintainer_access_group) { false }
  end
end
