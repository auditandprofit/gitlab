# frozen_string_literal: true

module Gitlab
  module Ai
    module SelfHosted
      module AiGateway
        extend self

        def probes(user)
          [
            ::CloudConnector::StatusChecks::Probes::SelfHosted::AiGatewayUrlPresenceProbe.new,
            ::CloudConnector::StatusChecks::Probes::HostProbe.new(::Gitlab::AiGateway.self_hosted_url),
            ::CloudConnector::StatusChecks::Probes::SelfHosted::CodeSuggestionsLicenseProbe.new(user)
          ]
        end
      end
    end
  end
end
