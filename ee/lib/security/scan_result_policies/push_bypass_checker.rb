# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class PushBypassChecker
      include Gitlab::Utils::StrongMemoize

      def initialize(project:, user_access:, branch_name:)
        @project = project
        @user_access = user_access
        @branch_name = branch_name
      end

      def check_bypass!
        return unless project.licensed_feature_available?(:security_orchestration_policies)

        policies = project.security_policies.with_bypass_settings
        return if policies.empty?

        policies.any? { |policy| bypass_allowed?(policy) }
      end

      private

      attr_reader :project, :user_access, :branch_name

      def bypass_allowed?(policy)
        Security::ScanResultPolicies::PolicyBypassChecker.new(
          security_policy: policy,
          project: project,
          user_access: user_access,
          branch_name: branch_name
        ).bypass_allowed?
      end
    end
  end
end
