# frozen_string_literal: true

module EE
  module Ci
    module RegisterJobService
      extend ::Gitlab::Utils::Override

      override :pre_assign_runner_checks
      def pre_assign_runner_checks
        super.merge({
          ip_restriction_failure: ->(build, _) { build.project.group && !::Gitlab::IpRestriction::Enforcer.new(build.project.group).allows_current_ip? },
          secrets_provider_not_found: ->(build, _) { secrets_provider_not_found?(build) }
        })
      end

      private

      def secrets_provider_not_found?(build)
        return false unless build.ci_secrets_management_available?
        return false unless build.secrets?

        !build.secrets_provider?(build.secrets)
      end
    end
  end
end
