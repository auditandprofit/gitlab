# frozen_string_literal: true

module SecretsManagement
  module ProjectSecrets
    class CreateService < BaseService
      include Gitlab::Utils::StrongMemoize
      include SecretsManagerClientHelpers
      include CiPolicies::SecretRefresherHelper
      include Helpers::UserClientHelper

      # MAX_SECRET_SIZE sets the maximum size of a secret value; see note
      # below before removing.
      MAX_SECRET_SIZE = 10000

      def execute(name:, value:, environment:, branch:, description: nil)
        project_secret = ProjectSecret.new(
          name: name,
          description: description,
          project: project,
          branch: branch,
          environment: environment
        )

        store_secret(project_secret, value)
      end

      private

      delegate :secrets_manager, to: :project

      def store_secret(project_secret, value)
        return error_response(project_secret) unless project_secret.valid?

        # Before removing value from the above and sending value directly
        # to OpenBao, ensure it has been updated with request parameter
        # size limiting quotas.
        if value.bytesize > MAX_SECRET_SIZE
          project_secret.errors.add(:base, "Length of project secret value exceeds allowed limits (10k bytes).")
          return error_response(project_secret)
        end

        # The follow API calls are ordered such that they fail closed: first we
        # create the secret and its metadata and then attach policy to it. If we
        # fail to attach policy, no pipelines can access it and only project-level
        # users can modify it in the future. Updating a secret to set missing
        # branch and environments will then allow pipelines to access the secret.

        create_secret(project_secret, value)

        refresh_secret_ci_policies(project_secret)

        project_secret.metadata_version = 1

        ServiceResponse.success(payload: { project_secret: project_secret })
      rescue SecretsManagerClient::ApiError => e
        raise e unless e.message.include?('check-and-set parameter did not match the current version')

        project_secret.errors.add(:base, 'Project secret already exists.')
        error_response(project_secret)
      end

      # NOTE: The current implementation makes two separate API calls (one for the value, one for metadata).
      # In the future, the secret value creation will be handled directly in the frontend for better security,
      # before calling this service. However, the metadata update and policy management will still be handled
      # in this Rails backend service, as they contain essential information for access control.
      def create_secret(project_secret, value)
        user_client.update_kv_secret(
          secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(project_secret.name),
          value,
          cas: 0
        )

        custom_metadata = {
          environment: project_secret.environment,
          branch: project_secret.branch,
          description: project_secret.description
        }.compact

        user_client.update_kv_secret_metadata(
          secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(project_secret.name),
          custom_metadata,
          metadata_cas: 0
        )
      end

      def error_response(project_secret)
        ServiceResponse.error(
          message: project_secret.errors.full_messages.to_sentence,
          payload: { project_secret: project_secret }
        )
      end
    end
  end
end
