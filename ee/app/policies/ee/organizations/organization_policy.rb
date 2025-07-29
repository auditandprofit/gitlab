# frozen_string_literal: true

module EE
  module Organizations
    module OrganizationPolicy
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      prepended do
        include RemoteDevelopment::OrganizationPolicy

        condition(:dependency_scanning_enabled) do
          License.feature_available?(:dependency_scanning)
        end

        condition(:license_scanning_enabled) do
          License.feature_available?(:license_scanning)
        end

        rule { (admin | organization_user) & dependency_scanning_enabled }.enable :read_dependency
        rule { (admin | organization_user) & license_scanning_enabled }.enable :read_licenses
      end
    end
  end
end
