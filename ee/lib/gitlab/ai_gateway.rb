# frozen_string_literal: true

module Gitlab
  module AiGateway
    ForbiddenError = Class.new(StandardError)
    ClientError = Class.new(StandardError)
    ServerError = Class.new(StandardError)

    FEATURE_FLAG_CACHE_KEY = "gitlab_ai_gateway_feature_flags"
    CURRENT_CONTEXT_CACHE_KEY = "gitlab_ai_gateway_current_context"

    def self.url
      self_hosted_url || cloud_connector_url
    end

    def self.cloud_connector_url
      "#{::CloudConnector::Config.base_url}/ai"
    end

    def self.access_token_url
      base_url = self_hosted_url || "#{::CloudConnector::Config.base_url}/auth"

      "#{base_url}/v1/code/user_access_token"
    end

    def self.self_hosted_url
      ::Ai::Setting.instance&.ai_gateway_url || ENV["AI_GATEWAY_URL"]
    end

    def self.enabled_instance_verbose_ai_logs
      ::Ai::Setting.instance&.enabled_instance_verbose_ai_logs.to_s || ''
    end

    # Exposes the state of a feature flag to the AI Gateway code.
    #
    # name - The name of the feature flag, e.g. `my_feature`.
    # args - Any additional arguments to pass to `Feature.enabled?`. This allows
    #        you to check if a flag is enabled for a particular user.
    def self.push_feature_flag(name, *args, **kwargs)
      enabled = Feature.enabled?(name, *args, **kwargs)

      return unless enabled

      enabled_feature_flags.append(name)
    end

    def self.current_context
      Gitlab::SafeRequestStore.fetch(CURRENT_CONTEXT_CACHE_KEY) { {} }
    end

    # Appended feature flags to the current context.
    # We use SafeRequestStore for the context management which refresh the cache per API request or Sidekiq job run.
    # See https://gitlab.com/gitlab-org/gitlab/-/blob/master/gems/gitlab-safe_request_store/README.md
    def self.enabled_feature_flags
      Gitlab::SafeRequestStore.fetch(FEATURE_FLAG_CACHE_KEY) { [] }
    end

    def self.headers(user:, service:, agent: nil, lsp_version: nil)
      {
        'X-Gitlab-Authentication-Type' => 'oidc',
        'Authorization' => "Bearer #{service.access_token(user)}",
        'Content-Type' => 'application/json',
        'X-Gitlab-Is-Team-Member' =>
          (::Gitlab::Tracking::StandardContext.new.gitlab_team_member?(user&.id) || false).to_s,
        'X-Request-ID' => Labkit::Correlation::CorrelationId.current_or_new_id,
        # Forward the request time to the model gateway to calculate latency
        'X-Gitlab-Rails-Send-Start' => Time.now.to_f.to_s
      }.merge(public_headers(user: user, service_name: service.name))
        .tap do |result|
          result['User-Agent'] = agent if agent # Forward the User-Agent on to the model gateway
          if current_context[:x_gitlab_client_type]
            result['X-Gitlab-Client-Type'] = current_context[:x_gitlab_client_type]
          end

          if current_context[:x_gitlab_client_version]
            result['X-Gitlab-Client-Version'] = current_context[:x_gitlab_client_version]
          end

          if current_context[:x_gitlab_client_name]
            result['X-Gitlab-Client-Name'] = current_context[:x_gitlab_client_name]
          end

          result['X-Gitlab-Interface'] = current_context[:x_gitlab_interface] if current_context[:x_gitlab_interface]

          if lsp_version
            # Forward the X-Gitlab-Language-Server-Version on to the model gateway
            result['X-Gitlab-Language-Server-Version'] = lsp_version
          end

          # Pass the distrubted tracing LangSmith header to AI Gateway.
          result.merge!(Langsmith::RunHelpers.to_headers) if Langsmith::RunHelpers.enabled?
        end
    end

    def self.public_headers(user:, service_name:)
      auth_response = user&.allowed_to_use(service_name)
      enablement_type = auth_response&.enablement_type || ''
      namespace_ids = auth_response&.namespace_ids || []

      {
        'x-gitlab-feature-enablement-type' => enablement_type,
        'x-gitlab-enabled-feature-flags' => enabled_feature_flags.uniq.join(','),
        'x-gitlab-enabled-instance-verbose-ai-logs' => enabled_instance_verbose_ai_logs
      }.merge(::CloudConnector.ai_headers(user, namespace_ids: namespace_ids))
    end
  end
end
