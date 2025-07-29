# frozen_string_literal: true

module Mutations
  module SecretsManagement
    module Permissions
      class Delete < BaseMutation
        graphql_name 'SecretPermissionDelete'

        include ResolvesProject

        authorize :admin_project_secrets_manager

        argument :project_path, GraphQL::Types::ID,
          required: true,
          description: 'Project permissions for the secret.'

        argument :principal, Types::SecretsManagement::Permissions::PrincipalInputType,
          required: true,
          description: 'Whose permission to be deleted.'

        field :secret_permission, Types::SecretsManagement::Permissions::SecretPermissionType,
          null: true,
          description: 'Deleted Secret Permission.'

        def resolve(project_path:, principal:)
          project = authorized_find!(project_path: project_path)

          if Feature.disabled?(:secrets_manager, project)
            raise_resource_not_available_error!("`secrets_manager` feature flag is disabled.")
          end

          result = ::SecretsManagement::Permissions::DeleteService
            .new(project, current_user)
            .execute(principal: principal)

          if result.success?
            {
              secret_permission: result.payload[:secret_permission],
              errors: []
            }
          else
            {
              secret_permission: nil,
              errors: [result.message]
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
