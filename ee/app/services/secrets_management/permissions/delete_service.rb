# frozen_string_literal: true

module SecretsManagement
  module Permissions
    class DeleteService < BaseService
      include SecretsManagerClientHelpers
      include ErrorResponseHelper

      def execute(principal:)
        secrets_manager = project.secrets_manager
        return inactive_response unless secrets_manager&.active?

        return invalid_principal_response unless valid_principal?(principal)

        secret_permission = secrets_manager.generate_policy_name(project_id: project.id,
          principal_type: principal[:type],
          principal_id: principal[:id])

        delete_permission(secret_permission)
      end

      private

      def delete_permission(secret_permission)
        secrets_manager_client.delete_policy(secret_permission)
        ServiceResponse.success(payload: { secret_permission: nil })
      rescue SecretsManagement::SecretsManagerClient::ConnectionError => e
        ServiceResponse.error(message: "Failed to delete permission: #{e.message}",
          payload: { secret_permission: nil })
      end

      def valid_principal?(principal)
        return false if principal.blank? || principal[:type].blank? || principal[:id].blank?

        valid_type = SecretsManagement::SecretPermission::VALID_PRINCIPAL_TYPES.include?(principal[:type])
        valid_id = principal[:id].to_s.match?(/\A\d+\z/)
        valid_type && valid_id
      end

      def invalid_principal_response
        ServiceResponse.error(message: 'Invalid principal')
      end
    end
  end
end
