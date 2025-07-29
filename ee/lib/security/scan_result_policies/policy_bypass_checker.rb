# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class PolicyBypassChecker
      include Gitlab::Utils::StrongMemoize

      def initialize(security_policy:, project:, user_access:, branch_name:)
        @security_policy = security_policy
        @project = project
        @user = user_access.user
        @branch_name = branch_name
      end

      def bypass_allowed?
        return false unless user

        bypass_with_access_token? || bypass_with_service_account?
      end

      def bypass_with_access_token?
        policy_token_ids = security_policy.bypass_settings.access_token_ids
        return false if policy_token_ids.blank?

        return false unless user.project_bot?

        user_token_ids = user.personal_access_tokens.active.id_in(policy_token_ids).pluck_primary_key
        return false if user_token_ids.blank?

        log_bypass_audit!(:access_token, user_token_ids)
        true
      end

      def bypass_with_service_account?
        policy_service_account_ids = security_policy.bypass_settings.service_account_ids
        return false if policy_service_account_ids.blank?

        return false unless user.service_account?
        return false unless policy_service_account_ids.include?(user.id)

        log_bypass_audit!(:service_account, user.id)
        true
      end

      private

      attr_reader :security_policy, :project, :user, :branch_name

      def log_bypass_audit!(type, id)
        message = <<~MSG.squish
          Branch push restriction on '#{branch_name}' for project '#{project.full_path}'
          has been bypassed by #{type} with ID: #{id}
        MSG

        Gitlab::Audit::Auditor.audit(
          name: "security_policy_#{type}_push_bypass",
          author: user,
          scope: security_policy.security_policy_management_project,
          target: security_policy,
          message: message,
          additional_details: {
            project_id: project.id,
            security_policy_name: security_policy.name,
            security_policy_id: security_policy.id,
            branch_name: branch_name
          }
        )
      end
    end
  end
end
