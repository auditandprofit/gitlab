# frozen_string_literal: true

module SecretsManagement
  module CiPolicies
    class SecretRefresher
      def initialize(secrets_manager, secrets_manager_client)
        @secrets_manager = secrets_manager
        @secrets_manager_client = secrets_manager_client
      end

      def refresh_ci_policies_for(secret, delete: false)
        policy_to_be_removed_from, policy_to_be_added_to = affected_policies(secret, delete)
        analysis = analyze_policies(count_secrets_for: policy_to_be_removed_from)

        if policy_to_be_removed_from
          remove_secret_from_policy(
            secret,
            policy_to_be_removed_from,
            delete_policy: analysis[:policy_secrets_count] == 0)
        end

        if policy_to_be_added_to
          # For both new secrets and updated secrets (with or without policy transitions)
          add_secret_to_policy(secret, policy_to_be_added_to)
        end

        update_jwt_role_token_policies(analysis[:glob_policies])
      end

      private

      attr_reader :secrets_manager, :secrets_manager_client

      delegate :ci_policy_name, to: :secrets_manager

      def affected_policies(secret, delete)
        if delete
          [
            ci_policy_name(secret.environment, secret.branch),
            nil
          ]
        elsif needs_policy_transition?(secret)
          [
            ci_policy_name(secret.environment_was, secret.branch_was),
            ci_policy_name(secret.environment, secret.branch)
          ]
        else
          [
            nil,
            ci_policy_name(secret.environment, secret.branch)
          ]
        end
      end

      def needs_policy_transition?(secret)
        return false unless secret.environment_changed? || secret.branch_changed?

        secret.environment_was.present? || secret.branch_was.present?
      end

      def remove_secret_from_policy(secret, policy_name, delete_policy: false)
        if delete_policy
          # No other secrets use this policy, delete it entirely
          secrets_manager_client.delete_policy(policy_name)
        else
          # Just remove this specific secret from the shared policy
          remove_secret_paths_from_policy(policy_name, secret.name)
        end
      end

      def remove_secret_paths_from_policy(policy_name, secret_name)
        policy = secrets_manager_client.get_policy(policy_name)
        policy.remove_capability(secrets_manager.ci_full_path(secret_name), "read")
        policy.remove_capability(secrets_manager.ci_metadata_full_path(secret_name), "read")
        secrets_manager_client.set_policy(policy)
      end

      def add_secret_to_policy(secret, policy_name)
        policy = secrets_manager_client.get_policy(policy_name)
        policy.add_capability(
          secrets_manager.ci_full_path(secret.name),
          "read"
        )
        policy.add_capability(
          secrets_manager.ci_metadata_full_path(secret.name),
          "read"
        )
        secrets_manager_client.set_policy(policy)
      end

      # Analyze secrets with a single scan - efficiently checking for a specific policy
      # and collecting all glob policies in one pass
      def analyze_policies(count_secrets_for:)
        policy_secrets_count = 0
        glob_policies = Set.new

        secrets_manager_client.list_secrets(
          secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_root_path
        ) do |secret|
          metadata = secret['metadata']
          next unless metadata

          environment = metadata.dig('custom_metadata', 'environment')
          branch = metadata.dig('custom_metadata', 'branch')
          next unless environment && branch

          secret_policy_name = secrets_manager.ci_policy_name(environment, branch)
          policy_secrets_count = policy_secrets_count.to_i + 1 if secret_policy_name == count_secrets_for

          # For wildcards, collect glob policies
          if environment.include?('*') || branch.include?('*')
            policies = secrets_manager.ci_auth_glob_policies(environment, branch)
            glob_policies.merge(policies)
          end
        end

        {
          policy_secrets_count: policy_secrets_count,
          glob_policies: glob_policies
        }
      end

      # Update JWT role based on wildcard policies
      def update_jwt_role_token_policies(glob_policies)
        role = secrets_manager_client.read_jwt_role(
          secrets_manager.ci_auth_mount,
          secrets_manager.ci_auth_role
        )

        # Start with the literal policies
        updated_policies = Set.new(secrets_manager.ci_auth_literal_policies)

        # Add all the glob policies we've collected
        updated_policies.merge(glob_policies)

        # Update the JWT role
        role['token_policies'] = updated_policies.to_a
        secrets_manager_client.update_jwt_role(
          secrets_manager.ci_auth_mount,
          secrets_manager.ci_auth_role,
          **role
        )
      end
    end
  end
end
