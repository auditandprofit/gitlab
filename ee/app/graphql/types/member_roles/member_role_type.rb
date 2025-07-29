# frozen_string_literal: true

module Types
  module MemberRoles
    # Anyone who can update group/project members can also read member roles
    # But it is too complex to be included on a simple MemberRole type
    #
    # rubocop: disable Graphql/AuthorizeTypes -- authorization too complex
    class MemberRoleType < BaseObject
      graphql_name 'MemberRole'
      description 'Represents a member role'

      implements Types::Members::RoleInterface
      implements Types::Members::CustomRoleInterface
      implements Types::Members::MemberRoleInterface

      field :base_access_level,
        Types::AccessLevelType,
        null: false,
        experiment: { milestone: '16.5' },
        description: 'Base access level for the custom role.'

      field :enabled_permissions,
        ::Types::Members::CustomizableStandardPermissionType.connection_type,
        null: false,
        experiment: { milestone: '16.5' },
        description: 'Array of all permissions enabled for the custom role.'

      field :dependent_security_policies,
        [::Types::SecurityOrchestration::ApprovalPolicyType],
        null: true,
        description: 'Array of security policies dependent on the custom role.',
        resolver: ::Resolvers::Members::ApprovalPolicyResolver

      def enabled_permissions
        object.enabled_permissions(current_user).keys
      end

      def details_path
        member_role_details_path(object)
      end
    end
    # rubocop: enable Graphql/AuthorizeTypes
  end
end
