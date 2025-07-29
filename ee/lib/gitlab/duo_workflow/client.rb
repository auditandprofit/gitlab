# frozen_string_literal: true

module Gitlab
  module DuoWorkflow
    class Client
      def self.url
        Gitlab.config.duo_workflow.service_url || default_service_url
      end

      def self.default_service_url
        subdomain = ::CloudConnector::Config.host.include?('staging') ? '.staging' : ''

        # Cloudflare has been disabled untill
        # gets resolved https://gitlab.com/gitlab-org/gitlab/-/issues/509586
        # "#{::CloudConnector::Config.host}:#{::CloudConnector::Config.port}"
        "duo-workflow-svc#{subdomain}.runway.gitlab.net:#{::CloudConnector::Config.port}"
      end

      def self.headers(user:)
        ::CloudConnector.ai_headers(user)
      end

      def self.secure?
        !!Gitlab.config.duo_workflow.secure
      end

      def self.debug_mode?
        !!Gitlab.config.duo_workflow.debug
      end

      def self.cloud_connector_headers(user:)
        Gitlab::AiGateway
          .public_headers(user: user, service_name: :duo_workflow)
          .transform_keys(&:downcase)
          .merge(
            'x-gitlab-base-url' => Gitlab.config.gitlab.url,
            'authorization' => "Bearer #{cloud_connector_token(user: user)}",
            'x-gitlab-authentication-type' => 'oidc'
          )
      end

      def self.cloud_connector_token(user:)
        ::CloudConnector::Tokens.get(
          unit_primitive: :duo_agent_platform,
          resource: user
        )
      end

      def self.metadata(user)
        {
          extended_logging: Feature.enabled?(:duo_workflow_extended_logging, user),
          is_team_member:
            ::Gitlab::Tracking::StandardContext.new.gitlab_team_member?(user&.id)
        }
      end
    end
  end
end
