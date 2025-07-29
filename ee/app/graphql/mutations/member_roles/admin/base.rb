# frozen_string_literal: true

module Mutations
  module MemberRoles
    module Admin
      # rubocop:disable GraphQL/GraphqlName -- This is a base mutation so name is not needed here
      class Base < ::Mutations::MemberRoles::Base
        argument :permissions,
          [Types::Members::CustomizableAdminPermissionsEnum],
          required: false,
          description: 'List of all customizable admin permissions.'

        field :member_role,
          ::Types::Members::AdminMemberRoleType,
          description: 'Member role.',
          null: true

        def ready?(**args)
          unless Feature.enabled?(:custom_admin_roles, :instance)
            raise_resource_not_available_error! '`custom_admin_roles` feature flag is disabled.'
          end

          super
        end
      end
      # rubocop:enable GraphQL/GraphqlName
    end
  end
end
