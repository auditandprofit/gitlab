# frozen_string_literal: true

module EE
  module PersonalAccessTokenPolicy # rubocop:disable Gitlab/BoundedContexts -- Existing policy with EE extension.
    extend ActiveSupport::Concern

    prepended do
      condition(:is_enterprise_user_manager) { user && subject.user.managed_by_user?(user) }
      condition(:is_service_account_group_owner) do
        user && subject.user.service_account? && subject.user.provisioned_by_group&.owned_by?(user)
      end
      condition(:group_credentials_inventory_available) do
        ::Gitlab::Saas.feature_available?(:group_credentials_inventory)
      end

      rule { is_enterprise_user_manager & group_credentials_inventory_available }.policy do
        enable :revoke_token
        enable :rotate_token
      end
      rule { is_service_account_group_owner & group_credentials_inventory_available }.policy do
        enable :revoke_token
      end
    end
  end
end
