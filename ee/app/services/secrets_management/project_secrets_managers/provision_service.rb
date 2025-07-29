# frozen_string_literal: true

module SecretsManagement
  module ProjectSecretsManagers
    class ProvisionService < BaseService
      include SecretsManagerClientHelpers

      SECRETS_ENGINE_TYPE = 'kv-v2'
      OWNER_PRINCIPAL_ID = Gitlab::Access.sym_options_with_owner[:owner]
      OWNER_PRINCIPAL_TYPE = "Role"
      OWNER_PERMISSIONS = %w[create update delete read list scan].freeze

      def initialize(secrets_manager, current_user)
        super(secrets_manager.project, current_user)

        @secrets_manager = secrets_manager
      end

      def execute
        enable_secret_store
        enable_auth
        create_owner_policy

        activate_secrets_manager
        ServiceResponse.success(payload: { project_secrets_manager: secrets_manager })
      end

      private

      def enable_secret_store
        secrets_manager_client.enable_secrets_engine(secrets_manager.ci_secrets_mount_path, SECRETS_ENGINE_TYPE)
      rescue SecretsManagerClient::ApiError => e
        raise e unless e.message.include?('path is already in use')

        # This scenario may happen in a rare event that the API call to enable the engine succeeds
        # but the actual column update failed due to unexpected reasons (e.g. network hiccups) that
        # will also fail the job. So on job retry, we want to ignore this message and continue
        # with the column update.
      end

      def enable_auth
        # configure pipeline auth
        pipeline_jwt_exists = enable_auth_engine(secrets_manager.ci_auth_mount, secrets_manager.ci_auth_type)
        configure_auth(pipeline_jwt_exists)
        # configure user auth
        user_jwt_exists = enable_auth_engine(secrets_manager.user_auth_mount, secrets_manager.user_auth_type)
        configure_user_auth(user_jwt_exists)
      end

      def enable_auth_engine(auth_mount, auth_type)
        secrets_manager_client.enable_auth_engine(
          auth_mount,
          auth_type,
          allow_existing: true
        )
      end

      def configure_auth(jwt_exists)
        unless jwt_exists
          # We use the OIDC discovery URL to configure this JWT mount so that
          # OpenBao can automatically update its copy of the issuer. However,
          # if we're running under a spec, we'll use a hard-coded JKS instead
          # so that we don't need a full Puma instance running.
          issuer_base_url = ProjectSecretsManager.jwt_issuer
          issuer_key = Gitlab::CurrentSettings.ci_jwt_signing_key
          secrets_manager_client.configure_jwt(secrets_manager.ci_auth_mount, issuer_base_url, issuer_key)
        end

        secrets_manager_client.update_jwt_role(
          secrets_manager.ci_auth_mount,
          secrets_manager.ci_auth_role,
          role_type: 'jwt',
          token_policies_template_claims: true,
          token_policies: secrets_manager.ci_auth_literal_policies,
          bound_claims: {
            project_id: secrets_manager.project.id.to_s
          },
          bound_audiences: [ProjectSecretsManager.server_url],
          user_claim: "project_id",
          token_type: "service"
        )
      end

      def configure_user_auth(jwt_exists)
        unless jwt_exists
          # We use the OIDC discovery URL to configure this JWT mount so that
          # OpenBao can automatically update its copy of the issuer. However,
          # if we're running under a spec, we'll use a hard-coded JKS instead
          # so that we don't need a full Puma instance running.
          issuer_base_url = ProjectSecretsManager.jwt_issuer
          issuer_key = Gitlab::CurrentSettings.ci_jwt_signing_key
          secrets_manager_client.configure_jwt(secrets_manager.user_auth_mount, issuer_base_url, issuer_key)
        end

        secrets_manager_client.update_jwt_role(
          secrets_manager.user_auth_mount,
          secrets_manager.user_auth_role,
          role_type: 'jwt',
          token_policies_template_claims: true,
          token_policies: secrets_manager.user_auth_policies,
          bound_claims: {
            project_id: secrets_manager.project.id.to_s
          },
          bound_audiences: [ProjectSecretsManager.server_url],
          user_claim: "user_id",
          token_type: "service"
        )
      end

      def create_owner_policy
        policy_name = secrets_manager.generate_policy_name(
          project_id: secrets_manager.project.id,
          principal_type: OWNER_PRINCIPAL_TYPE,
          principal_id: OWNER_PRINCIPAL_ID
        )

        policy = SecretsManagement::AclPolicy.new(policy_name)
        update_policy_paths(policy, OWNER_PERMISSIONS)
        secrets_manager_client.set_policy(policy)
      rescue SecretsManagement::SecretsManagerClient::ApiError => e
        Gitlab::AppLogger.error("Failed to create owner policy for project #{secrets_manager.project.id}: #{e.message}")
        raise e
      end

      def update_policy_paths(policy, permissions)
        data_path = secrets_manager.ci_full_path('*')
        metadata_path = secrets_manager.ci_metadata_full_path('*')
        detailed_metadata_path = secrets_manager.detailed_metadata_path('*')

        # Add new capabilities
        permissions.each do |permission|
          policy.add_capability(data_path, permission) if permission != 'read'
          policy.add_capability(metadata_path, permission)
        end
        policy.add_capability(detailed_metadata_path, 'list')
      end

      def activate_secrets_manager
        return if secrets_manager.active?

        secrets_manager.activate!
      end

      attr_reader :secrets_manager
    end
  end
end
