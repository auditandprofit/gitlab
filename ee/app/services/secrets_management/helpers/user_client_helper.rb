# frozen_string_literal: true

module SecretsManagement
  module Helpers
    module UserClientHelper
      include Gitlab::Utils::StrongMemoize

      def user_client
        user_jwt = UserJwt.new(
          current_user: current_user,
          project: project
        ).encoded

        SecretsManagerClient.new(jwt: user_jwt, role: project.secrets_manager.user_auth_role,
          auth_mount: project.secrets_manager.user_auth_mount)
      end
      strong_memoize_attr :user_client
    end
  end
end
