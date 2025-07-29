# frozen_string_literal: true

module SecretsManagement
  module CiPolicies
    module SecretRefresherHelper
      def refresh_secret_ci_policies(project_secret, delete: false)
        refresher = SecretRefresher.new(secrets_manager, secrets_manager_client)
        refresher.refresh_ci_policies_for(project_secret, delete: delete)
      end
    end
  end
end
