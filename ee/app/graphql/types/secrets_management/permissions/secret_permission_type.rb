# frozen_string_literal: true

module Types
  module SecretsManagement
    module Permissions
      class SecretPermissionType < BaseObject
        graphql_name 'SecretPermission'
        description 'Representation of a secrets permission.'

        authorize :admin_project_secrets_manager

        field :project,
          Types::ProjectType,
          null: false,
          description: 'Project the secret permission belong to.'

        field :principal,
          Types::SecretsManagement::Permissions::PrincipalType,
          null: false,
          description: 'Who is provided access to. For eg: User/Role/MemberRole/Group.'

        field :permissions,
          type: GraphQL::Types::String,
          null: false,
          description: "Permissions to be provided. ['create', 'update', 'read', 'delete']."

        # Will be updating the granted_by to the current_user in a separate MR.
        field :granted_by,
          type: GraphQL::Types::String,
          null: true,
          description: "User who created the Secret Permission (optional)."

        field :expired_at,
          type: GraphQL::Types::ISO8601Date,
          null: true,
          description: "Expiration date for Secret Permission (optional)."

        def principal
          {
            id: object.principal_id.to_s,
            type: object.principal_type.to_s
          }
        end
      end
    end
  end
end
