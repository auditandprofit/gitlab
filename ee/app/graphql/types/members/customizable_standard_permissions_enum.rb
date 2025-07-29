# frozen_string_literal: true

module Types
  module Members
    class CustomizableStandardPermissionsEnum < BaseEnum
      graphql_name 'MemberRoleStandardPermission'
      description 'Member role standard permission'

      include CustomizablePermission

      MemberRole.all_customizable_standard_permissions.each_pair do |key, value|
        define_permission(key, value)
      end
    end
  end
end
