# frozen_string_literal: true

module Authz
  module AdminRollable
    extend ActiveSupport::Concern

    included do
      before_destroy :prevent_delete_if_associated, if: :admin_related_role?
    end

    class_methods do
      def all_customizable_admin_permissions
        Gitlab::CustomRoles::Definition.admin
      end

      def all_customizable_admin_permission_keys
        Gitlab::CustomRoles::Definition.admin.keys
      end

      def admin_permission_enabled?(permission)
        return false unless ::Feature.enabled?(:custom_admin_roles, :instance)
        return true unless ::Feature::Definition.get("custom_ability_#{permission}")

        ## this feature flag name 'pattern' is used for all custom roles so we can't
        ## avoid dynamically passing in the name to Feature.*abled?
        ::Feature.enabled?("custom_ability_#{permission}", :instance) # rubocop:disable FeatureFlagKeyDynamic -- see above
      end
    end

    def enabled_admin_permissions
      self.class.all_customizable_admin_permissions.filter do |permission|
        attributes[permission.to_s] && self.class.admin_permission_enabled?(permission)
      end
    end

    # Stop the process of deletion in this callback. Otherwise,
    # deletion would proceed even if we make the object invalid.
    def prevent_delete_if_associated
      if user_member_roles.present?
        errors.add(:base,
          s_("MemberRole|Admin role is assigned to one or more users. " \
            "Remove role from all users, then delete role."))

        throw :abort # rubocop:disable Cop/BanCatchThrow -- See above.
      elsif respond_to?(:ldap_admin_role_links) && ldap_admin_role_links.present?
        errors.add(:base,
          s_("MemberRole|Admin role is used by one or more LDAP synchronizations. " \
            "Remove LDAP syncs, then delete role."))

        throw :abort # rubocop:disable Cop/BanCatchThrow -- See above.
      end
    end
  end
end
