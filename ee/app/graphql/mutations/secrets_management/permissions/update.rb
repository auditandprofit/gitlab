# frozen_string_literal: true

module Mutations
  module SecretsManagement
    module Permissions
      class Update < BaseMutation
        graphql_name 'SecretPermissionUpdate'

        include ResolvesProject

        authorize :admin_project_secrets_manager

        argument :project_path, GraphQL::Types::ID,
          required: true,
          description: 'Project to which the permissions are added.'

        argument :principal, Types::SecretsManagement::Permissions::PrincipalInputType,
          required: true,
          description: 'User/MemberRole/Role/Group that is provided access.'

        argument :permissions, [::GraphQL::Types::String],
          required: true,
          description: "Permissions to be provided. ['create', 'update', 'read', 'delete']."

        argument :expired_at, GraphQL::Types::ISO8601Date, required: false,
          description: "Expiration date for Secret Permission (optional)."

        field :secret_permission, Types::SecretsManagement::Permissions::SecretPermissionType,
          null: true,
          description: 'Secret Permission that was created.'

        def resolve(project_path:, principal:, permissions:, expired_at: nil)
          project = authorized_find!(project_path: project_path)

          if Feature.disabled?(:secrets_manager, project)
            raise_resource_not_available_error!("`secrets_manager` feature flag is disabled.")
          end

          result = ::SecretsManagement::Permissions::UpdateService
            .new(project, current_user)
            .execute(principal_id: principal.id,
              principal_type: principal.type,
              permissions: permissions,
              expired_at: expired_at)

          if result.success?
            {
              secret_permission: result.payload[:secret_permission],
              errors: []
            }
          else
            {
              secret_permission: nil,
              errors: errors_on_object(result.payload[:secret_permission])
            }
          end
        end

        private

        def find_object(project_path:)
          resolve_project(full_path: project_path)
        end
      end
    end
  end
end
