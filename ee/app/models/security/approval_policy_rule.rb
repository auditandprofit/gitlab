# frozen_string_literal: true

module Security
  class ApprovalPolicyRule < ApplicationRecord
    include PolicyRule
    include EachBatch

    self.table_name = 'approval_policy_rules'

    enum :type, { scan_finding: 0, license_finding: 1, any_merge_request: 2 }, prefix: true

    belongs_to :security_policy, class_name: 'Security::Policy', inverse_of: :approval_policy_rules
    belongs_to :security_policy_management_project, class_name: 'Project'

    has_many :approval_policy_rule_project_links, class_name: 'Security::ApprovalPolicyRuleProjectLink'
    has_many :projects, through: :approval_policy_rule_project_links
    has_many :software_license_policies
    has_one :approval_project_rule
    has_many :approval_merge_request_rules
    has_many :violations, class_name: 'Security::ScanResultPolicyViolation'

    validates :typed_content, json_schema: { filename: "approval_policy_rule_content" }

    def self.by_policy_rule_index(policy_configuration, policy_index:, rule_index:)
      joins(:security_policy).find_by(
        rule_index: rule_index,
        security_policy: {
          security_orchestration_policy_configuration_id: policy_configuration.id,
          policy_index: policy_index
        }
      )
    end

    def licenses
      typed_content['licenses']
    end

    def license_states
      typed_content['license_states']
    end

    def license_types
      typed_content['license_types']
    end

    def policy_applies_to_target_branch?(target_branch, project)
      branches, branch_type = content.values_at("branches", "branch_type")

      return branches_apply_to_target_branch?(target_branch, branches) if branches

      branch_type_applies_to_target_branch?(target_branch, branch_type, project)
    end

    def branches_exempted_by_policy?(source_branch, target_branch)
      branch_exceptions = security_policy.policy_content.dig(:bypass_settings, :branches)
      return false if branch_exceptions.blank?

      branch_exceptions.any? do |branch_exception|
        source_branch_exception = branch_exception[:source]
        target_branch_exception = branch_exception[:target]

        branch_matches_exception?(source_branch, source_branch_exception) &&
          branch_matches_exception?(target_branch, target_branch_exception)
      end
    end

    private

    def branches_apply_to_target_branch?(target_branch, branches)
      return true if branches == []

      branches.any? do |pattern|
        RefMatcher.new(pattern).matches?(target_branch)
      end
    end

    def branch_type_applies_to_target_branch?(target_branch, branch_type, project)
      if branch_type == 'default'
        target_branch == project.default_branch
      else # MRAP's `branch_type` only support `default` or `protected`
        ::ProtectedBranch.protected?(project, target_branch)
      end
    end

    def branch_matches_exception?(branch, exception)
      if exception[:name].present?
        branch == exception[:name]
      elsif exception[:pattern].present?
        RefMatcher.new(exception[:pattern]).matches?(branch)
      end
    end
  end
end
