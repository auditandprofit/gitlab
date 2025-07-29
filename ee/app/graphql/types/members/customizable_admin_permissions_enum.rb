# frozen_string_literal: true

module Types
  module Members
    class CustomizableAdminPermissionsEnum < BaseEnum
      graphql_name 'MemberRoleAdminPermission'
      description 'Member role admin permission'

      include CustomizablePermission

      MemberRole.all_customizable_admin_permissions.each_pair do |key, value|
        define_permission(key, value, feature_flag: :custom_admin_roles)
      end
    end
  end
end
