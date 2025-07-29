# frozen_string_literal: true

module EE
  module Ci
    module BuildRunnerPresenter
      extend ActiveSupport::Concern

      def secrets_configuration
        secrets.to_h.transform_values do |secret|
          secret['vault']['server'] = vault_server(secret) if secret['vault']
          secret['azure_key_vault']['server'] = azure_key_vault_server(secret) if secret['azure_key_vault']
          secret['gcp_secret_manager']['server'] = gcp_secret_manager_server(secret) if secret['gcp_secret_manager']

          if ::Feature.enabled?(:ci_akeyless_secret, project) && (secret['akeyless'])
            secret['akeyless']['server'] = akeyless_server(secret)
          end

          if ::Feature.enabled?(:ci_aws_secrets_manager, project) && (secret['aws_secrets_manager'])
            secret['aws_secrets_manager']['server'] = aws_secrets_manager_server(secret)
          end

          # For compatibility with the existing Vault integration in Runner,
          # template gitlab_secrets_manager data into the vault field.
          if secret.has_key?('gitlab_secrets_manager')
            # GitLab Secrets Manager and Vault integrations have different
            # structure; remove the old secret but save its data for later.
            gtsm_secret = secret.delete('gitlab_secrets_manager')

            psm = SecretsManagement::ProjectSecretsManager.find_by_project_id(project.id)

            # Compute full path to secret in OpenBao for Vault runner
            # compatibility.
            secret['vault'] = {}
            secret['vault']['path'] = psm.ci_data_path(gtsm_secret['name'])
            secret['vault']['engine'] = { name: "kv-v2", path: psm.ci_secrets_mount_path }
            secret['vault']['field'] = "value"

            # Tell Runner about our server information.
            secret['vault']['server'] = gitlab_secrets_manager_server(psm)
          end

          secret
        end
      end

      def policy_options
        return unless options[:execution_policy_job]

        {
          execution_policy_job: options[:execution_policy_job],
          policy_name: options[:execution_policy_name],
          policy_variables_override_allowed: options.dig(:execution_policy_variables_override, :allowed),
          policy_variables_override_exceptions: options.dig(:execution_policy_variables_override, :exceptions).presence
        }.compact
      end

      private

      def vault_server(secret)
        @vault_server ||= {
          'url' => variables['VAULT_SERVER_URL']&.value,
          'namespace' => variables['VAULT_NAMESPACE']&.value,
          'auth' => {
            'name' => 'jwt',
            'path' => variables['VAULT_AUTH_PATH']&.value || 'jwt',
            'data' => {
              'jwt' => vault_jwt(secret),
              'role' => variables['VAULT_AUTH_ROLE']&.value
            }.compact
          }
        }
      end

      def aws_secrets_manager_server(secret)
        @aws_secrets_manager_server ||= {
          'region' => variables['AWS_REGION']&.value,
          'jwt' => aws_token(secret),
          'role_arn' => variables['AWS_ROLE_ARN']&.value,
          'role_session_name' => variables['AWS_ROLE_SESSION_NAME']&.value
        }
      end

      def gitlab_secrets_manager_server(psm)
        @gitlab_secrets_manager_server ||= {
          'url' => SecretsManagement::ProjectSecretsManager.server_url,
          'auth' => {
            'name' => psm.ci_auth_type,
            'path' => psm.ci_auth_mount,
            'data' => {
              'jwt' => psm.ci_jwt(self),
              'role' => psm.ci_auth_role
            }.compact
          }
        }
      end

      def vault_jwt(secret)
        if id_tokens?
          id_token_var(secret)
        else
          '${CI_JOB_JWT}'
        end
      end

      def id_token_var(secret)
        secret['token'] || "$#{id_tokens.each_key.first}"
      end

      def aws_token(secret)
        secret['token'] || '$AWS_ID_TOKEN'
      end

      def gcp_secret_manager_server(secret)
        @gcp_secret_manager_server ||= {
          'project_number' => variables['GCP_PROJECT_NUMBER']&.value,
          'workload_identity_federation_pool_id' => variables['GCP_WORKLOAD_IDENTITY_FEDERATION_POOL_ID']&.value,
          'workload_identity_federation_provider_id' =>
            variables['GCP_WORKLOAD_IDENTITY_FEDERATION_PROVIDER_ID']&.value,
          'jwt' => secret['token']
        }
      end

      def akeyless_server(secret)
        @akeyless_server ||= {
          'access_id' => variables['AKEYLESS_ACCESS_ID']&.value,
          'access_key' => secret.dig('akeyless', 'akeyless_access_key'),
          'akeyless_api_url' => secret.dig('akeyless', 'akeyless_api_url') || "https://api.akeyless.io",
          'akeyless_access_type' => secret.dig('akeyless', 'akeyless_access_type') || "jwt",
          'akeyless_token' => secret.dig('akeyless', 'akeyless_token') || "",
          'uid_token' => secret.dig('akeyless', 'uid_token') || "",
          'gcp_audience' => secret.dig('akeyless', 'gcp_audience') || "",
          'azure_object_id' => secret.dig('akeyless', 'azure_object_id') || "",
          'k8s_service_account_token' => secret.dig('akeyless', 'k8s_service_account_token') || "",
          'k8s_auth_config_name' => secret.dig('akeyless', 'k8s_auth_config_name') || "",
          'gateway_ca_certificate' => secret.dig('akeyless', 'gateway_ca_certificate') || "",
          'jwt' => secret['token']
        }
      end

      def azure_key_vault_server(secret)
        @azure_key_vault_server ||= {
          'url' => variables['AZURE_KEY_VAULT_SERVER_URL']&.value,
          'client_id' => variables['AZURE_CLIENT_ID']&.value,
          'tenant_id' => variables['AZURE_TENANT_ID']&.value,
          'jwt' => azure_vault_jwt(secret)
        }
      end

      def azure_vault_jwt(secret)
        if id_tokens?
          id_token_var(secret)
        else
          '${CI_JOB_JWT_V2}'
        end
      end
    end
  end
end
