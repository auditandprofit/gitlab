# frozen_string_literal: true

module SecretsManagement
  module ProjectSecrets
    class ReadService < BaseService
      include Helpers::UserClientHelper

      def execute(name)
        return inactive_response unless project.secrets_manager&.active?
        return invalid_name_response unless /\A[a-zA-Z0-9_]+\z/.match?(name)

        secret_metadata = user_client.read_secret_metadata(
          project.secrets_manager.ci_secrets_mount_path,
          project.secrets_manager.ci_data_path(name)
        )

        if secret_metadata
          build_success_response(name, secret_metadata)
        else
          not_found_response
        end
      end

      private

      def build_success_response(name, secret_metadata)
        project_secret = ProjectSecret.new(
          name: name,
          project: project,
          description: secret_metadata["custom_metadata"]["description"],
          environment: secret_metadata["custom_metadata"]["environment"],
          branch: secret_metadata["custom_metadata"]["branch"],
          metadata_version: secret_metadata["current_metadata_version"]
        )

        ServiceResponse.success(payload: { project_secret: project_secret })
      end

      def inactive_response
        ServiceResponse.error(message: 'Project secrets manager is not active')
      end

      def not_found_response
        ServiceResponse.error(message: 'Project secret does not exist.', reason: :not_found)
      end

      def invalid_name_response
        ServiceResponse.error(message: "Name can contain only letters, digits and '_'.")
      end
    end
  end
end
