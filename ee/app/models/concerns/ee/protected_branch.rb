# frozen_string_literal: true

module EE
  module ProtectedBranch
    extend ActiveSupport::Concern

    prepended do
      has_and_belongs_to_many :approval_project_rules
      # NOTE: This is used to prevent N+1 queries in BranchRulesResolver
      has_and_belongs_to_many :approval_project_rules_with_unique_policies,
        ->(protected_branch) { with_unique_policies_for_protected_branch(protected_branch) },
        class_name: 'ApprovalProjectRule'
      has_and_belongs_to_many :external_status_checks, class_name: '::MergeRequests::ExternalStatusCheck'

      has_many :required_code_owners_sections, class_name: "ProtectedBranch::RequiredCodeOwnersSection"

      protected_ref_access_levels :unprotect

      scope :preload_access_levels, -> { preload(:push_access_levels, :merge_access_levels, :unprotect_access_levels) }

      attr_accessor :protected_from_deletion

      has_one :squash_option, class_name: 'Projects::BranchRules::SquashOption'
      has_one :merge_request_approval_setting, class_name: 'Projects::BranchRules::MergeRequestApprovalSetting'

      accepts_nested_attributes_for :squash_option, allow_destroy: true, update_only: true

      validate :exact_match_for_squash_option, if: :name_changed?
    end

    class_methods do
      def branch_requires_code_owner_approval?(project, branch_name)
        return false unless project.code_owner_approval_required_available?

        ::Gitlab::SafeRequestStore.fetch(:"project-#{project.id}-branch-#{branch_name}") do
          project.all_protected_branches.requiring_code_owner_approval.matching(branch_name).any?
        end
      end
    end

    def code_owner_approval_required
      super && entity.code_owner_approval_required_available?
    end
    alias_method :code_owner_approval_required?, :code_owner_approval_required

    def modification_blocked_by_policy?
      return false unless entity.licensed_feature_available?(:security_orchestration_policies)

      case entity
      when Project
        ::Security::SecurityOrchestrationPolicies::ProtectedBranchesDeletionCheckService
          .new(project: entity)
          .execute([self])
          .any?
      when Group
        ::Security::SecurityOrchestrationPolicies::GroupProtectedBranchesDeletionCheckService
          .new(group: entity)
          .execute
      end
    end
    alias_method :modification_blocked_by_policy, :modification_blocked_by_policy?

    def allow_force_push
      return false if protected_from_push_by_security_policy?

      super
    end

    def protected_from_push_by_security_policy?
      return false unless entity.licensed_feature_available?(:security_orchestration_policies)
      return false unless project_level?

      ::Security::SecurityOrchestrationPolicies::ProtectedBranchesPushService
        .new(project: project)
        .execute
        .include?(name)
    end

    def can_unprotect?(user)
      return true if unprotect_access_levels.empty?

      unprotect_access_levels.any? do |access_level|
        access_level.check_access(user)
      end
    end

    def supports_unprotection_restrictions?
      return false if group

      project.licensed_feature_available?(:unprotection_restrictions)
    end

    def inherited?
      !namespace_id.nil?
    end
    alias_method :inherited, :inherited?

    private

    def exact_match_for_squash_option
      return unless wildcard? && squash_option.present?
      return if squash_option.changed?

      errors.add(:squash_option, 'can only be configured for exact match branch rules')
    end
  end
end
