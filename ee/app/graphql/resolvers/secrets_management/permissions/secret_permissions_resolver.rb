# frozen_string_literal: true

module Resolvers
  module SecretsManagement
    module Permissions
      class SecretPermissionsResolver < BaseResolver
        include Gitlab::Graphql::Authorize::AuthorizeResource
        include ResolvesProject

        type [::Types::SecretsManagement::Permissions::SecretPermissionType], null: true

        argument :project_path, GraphQL::Types::ID,
          required: true,
          description: 'Project the secret permission belong to.'

        authorize :admin_project_secrets_manager

        def resolve(project_path:)
          project = authorized_find!(project_path: project_path)

          result = ::SecretsManagement::Permissions::ListService.new(
            project,
            current_user
          ).execute

          if result.success?
            result.payload[:secret_permissions]
          else
            raise_resource_not_available_error!(result.message)
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
