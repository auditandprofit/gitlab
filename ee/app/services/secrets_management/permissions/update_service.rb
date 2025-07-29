# frozen_string_literal: true

module SecretsManagement
  module Permissions
    class UpdateService < BaseService
      include SecretsManagerClientHelpers

      INTERNAL_PERMISSIONS = %w[list scan].freeze

      def execute(principal_id:, principal_type:, permissions:, expired_at:)
        secret_permission = SecretsManagement::SecretPermission.new(principal_id: principal_id,
          principal_type: principal_type,
          resource_type: 'Project',
          resource_id: project.id,
          permissions: permissions,
          granted_by: current_user.id,
          expired_at: expired_at,
          project: project)

        store_permission(secret_permission)
      end

      private

      delegate :secrets_manager, to: :project

      def store_permission(secret_permission)
        return error_response(secret_permission) unless secret_permission.valid?

        secret_permission.permissions = secret_permission.permissions + INTERNAL_PERMISSIONS

        # Get or create policy
        policy_name = secrets_manager.generate_policy_name(project_id: project.id,
          principal_type: secret_permission.principal_type,
          principal_id: secret_permission.principal_id)

        policy = secrets_manager_client.get_policy(policy_name)

        # If policy doesn't exist, create a new one
        policy ||= AclPolicy.new(policy_name)

        # Add or update paths with permissions
        update_policy_paths(policy, secret_permission.permissions)

        # Save the policy to OpenBao
        secrets_manager_client.set_policy(policy)

        # the list permission is only used internally and should not be returned to the user
        secret_permission.permissions = secret_permission.permissions - INTERNAL_PERMISSIONS

        ServiceResponse.success(payload: { secret_permission: secret_permission })
      rescue SecretsManagement::SecretsManagerClient::ApiError => e
        raise e unless e.message.include?('check-and-set parameter did not match the current version')

        secret_permission.errors.add(:base, "Failed to save secret_permission: #{e.message}")
        error_response(secret_permission)
      end

      def update_policy_paths(policy, permissions)
        data_path = secrets_manager.ci_full_path('*')
        metadata_path = secrets_manager.ci_metadata_full_path('*')
        detailed_metadata_path = secrets_manager.detailed_metadata_path('*')

        # Clear existing capabilities for these paths
        policy.paths[data_path].capabilities.clear if policy.paths[data_path]
        policy.paths[metadata_path].capabilities.clear if policy.paths[metadata_path]
        policy.paths[detailed_metadata_path].capabilities.clear if policy.paths[detailed_metadata_path]

        # Add new capabilities
        permissions.each do |permission|
          policy.add_capability(data_path, permission, user: current_user) if permission != 'read'
          policy.add_capability(metadata_path, permission, user: current_user)
        end
        policy.add_capability(detailed_metadata_path, 'list', user: current_user)
      end

      def error_response(secret_permission)
        ServiceResponse.error(
          message: secret_permission.errors.full_messages.to_sentence,
          payload: { secret_permission: secret_permission }
        )
      end
    end
  end
end
