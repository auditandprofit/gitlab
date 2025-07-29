# frozen_string_literal: true

module SecretsManagement
  module ProjectSecrets
    class UpdateService < BaseService
      include Gitlab::Utils::StrongMemoize
      include SecretsManagerClientHelpers
      include CiPolicies::SecretRefresherHelper
      include Helpers::UserClientHelper

      def execute(name:, metadata_cas: nil, value: nil, description: nil, environment: nil, branch: nil)
        return inactive_response unless project.secrets_manager&.active?

        read_result = read_project_secret(name)

        return read_result unless read_result.success?

        project_secret = read_result.payload[:project_secret]

        project_secret.description = description unless description.nil?
        project_secret.environment = environment unless environment.nil?
        project_secret.branch = branch unless branch.nil?

        # Update the secret
        update_secret(project_secret, value, metadata_cas)
      end

      private

      delegate :secrets_manager, to: :project

      def update_secret(project_secret, value, metadata_cas)
        return error_response(project_secret) unless project_secret.valid?

        custom_metadata = {
          environment: project_secret.environment,
          branch: project_secret.branch,
          description: project_secret.description
        }.compact

        # NOTE: The current implementation makes two separate API calls (one for the value, one for metadata).
        # In the future, the secret value update will be handled directly in the frontend for better security,
        # before calling this service. However, the metadata update and policy management will still be handled
        # in this Rails backend service, as they contain essential information for access control.

        # We need to do the metadata update first just in case the metadata_cas does not match
        user_client.update_kv_secret_metadata(
          secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(project_secret.name),
          custom_metadata,
          metadata_cas: metadata_cas
        )

        if value
          user_client.update_kv_secret(
            secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(project_secret.name),
            value
          )
        end

        refresh_secret_ci_policies(project_secret)

        project_secret.metadata_version = metadata_cas ? metadata_cas + 1 : nil

        ServiceResponse.success(payload: { project_secret: project_secret })
      rescue SecretsManagerClient::ApiError => e
        raise e unless e.message.include?('metadata check-and-set parameter does not match the current version')

        project_secret.errors.add(:base, e.message)
        error_response(project_secret)
      end

      def read_project_secret(name)
        read_service = ProjectSecrets::ReadService.new(project, current_user)
        read_service.execute(name)
      end

      def error_response(project_secret)
        ServiceResponse.error(
          message: project_secret.errors.full_messages.to_sentence,
          payload: { project_secret: project_secret }
        )
      end

      def inactive_response
        ServiceResponse.error(message: 'Project secrets manager is not active')
      end
    end
  end
end
