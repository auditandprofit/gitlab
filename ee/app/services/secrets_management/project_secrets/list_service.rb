# frozen_string_literal: true

module SecretsManagement
  module ProjectSecrets
    class ListService < BaseService
      include Helpers::UserClientHelper

      def execute
        return inactive_response unless project.secrets_manager&.active?

        secrets = user_client.list_secrets(
          project.secrets_manager.ci_secrets_mount_path,
          project.secrets_manager.ci_data_path
        ) do |data|
          custom_metadata = data.dig("metadata", "custom_metadata")

          ProjectSecret.new(
            name: data["key"],
            project: project,
            description: custom_metadata["description"],
            environment: custom_metadata["environment"],
            branch: custom_metadata["branch"],
            metadata_version: data.dig("metadata", "current_metadata_version")
          )
        end

        ServiceResponse.success(payload: { project_secrets: secrets })
      rescue StandardError => e
        ServiceResponse.error(message: e.message)
      end

      private

      def inactive_response
        ServiceResponse.error(message: 'Project secrets manager is not active')
      end
    end
  end
end
