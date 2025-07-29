# frozen_string_literal: true

module CloudConnector
  module StatusChecks
    # Runs several probes to determine whether features connected through Cloud Connector
    # are generally working. This includes checking for availability of certain network
    # endpoints, but also which license is used etc.
    class StatusService
      CUSTOMERS_DOT_URL = ::Gitlab::Routing.url_helpers.subscription_portal_url.freeze
      CLOUD_CONNECTOR_URL = ::CloudConnector::Config.base_url.freeze

      attr_reader :probes

      def initialize(user:, probes: nil)
        @user = user
        @probes = probes || selected_probes
      end

      def execute
        probe_results = probes.flat_map(&:execute)
        success = probe_results.all?(&:success?)
        payload = { probe_results: probe_results }

        return ServiceResponse.error(message: 'Some probes failed', payload: payload) unless success

        ServiceResponse.success(payload: payload)
      end

      private

      def selected_probes
        if ::Gitlab::Utils.to_boolean(ENV['CLOUD_CONNECTOR_SELF_SIGN_TOKENS'])
          development_probes
        # We consider the instance to be using self-hosted Duo
        # if they register a self-hosted AIGW URL.
        elsif ::Gitlab::AiGateway.self_hosted_url.present?
          ::Gitlab::Ai::SelfHosted::AiGateway.probes(@user)
        elsif ::Ai::AmazonQ.connected?
          default_probes + amazon_q_probes
        else
          default_probes
        end
      end

      def default_probes
        [
          CloudConnector::StatusChecks::Probes::LicenseProbe.new,
          CloudConnector::StatusChecks::Probes::HostProbe.new(CUSTOMERS_DOT_URL),
          CloudConnector::StatusChecks::Probes::HostProbe.new(CLOUD_CONNECTOR_URL),
          CloudConnector::StatusChecks::Probes::AccessProbe.new,
          CloudConnector::StatusChecks::Probes::TokenProbe.new,
          CloudConnector::StatusChecks::Probes::EndToEndProbe.new(@user)
        ]
      end

      # Carries out minimal checks for development and testing purposes
      def development_probes
        [
          CloudConnector::StatusChecks::Probes::HostProbe.new(::Gitlab::AiGateway.self_hosted_url),
          CloudConnector::StatusChecks::Probes::EndToEndProbe.new(@user)
        ]
      end

      def amazon_q_probes
        [
          CloudConnector::StatusChecks::Probes::AmazonQ::EndToEndProbe.new(@user)
        ]
      end
    end
  end
end
