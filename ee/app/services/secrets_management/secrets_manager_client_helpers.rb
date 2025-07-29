# frozen_string_literal: true

module SecretsManagement
  module SecretsManagerClientHelpers
    include Gitlab::Utils::StrongMemoize

    def secrets_manager_client
      jwt = SecretsManagerJwt.new(
        current_user: current_user,
        project: project
      ).encoded

      SecretsManagerClient.new(jwt: jwt)
    end
    strong_memoize_attr :secrets_manager_client
  end
end
