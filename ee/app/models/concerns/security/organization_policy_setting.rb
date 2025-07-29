# frozen_string_literal: true

module Security
  module OrganizationPolicySetting
    extend ActiveSupport::Concern
    include ::Gitlab::Utils::StrongMemoize

    included do
      delegate :csp_enabled?, to: :organization_policy_setting
    end

    private

    def organization_policy_setting
      ::Security::PolicySetting.for_organization(organization)
    end
    strong_memoize_attr :organization_policy_setting
  end
end
