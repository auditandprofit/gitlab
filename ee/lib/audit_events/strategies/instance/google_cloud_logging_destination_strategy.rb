# frozen_string_literal: true

module AuditEvents
  module Strategies
    module Instance
      class GoogleCloudLoggingDestinationStrategy < BaseGoogleCloudLoggingDestinationStrategy
        def streamable?
          ::License.feature_available?(:external_audit_events) &&
            AuditEvents::Instance::GoogleCloudLoggingConfiguration.active.exists?
        end

        private

        def destinations
          AuditEvents::Instance::GoogleCloudLoggingConfiguration.active.limit(5)
        end
      end
    end
  end
end
