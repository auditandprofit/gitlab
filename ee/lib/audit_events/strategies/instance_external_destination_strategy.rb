# frozen_string_literal: true

module AuditEvents
  module Strategies
    class InstanceExternalDestinationStrategy < ExternalDestinationStrategy
      def streamable?
        ::License.feature_available?(:external_audit_events) &&
          AuditEvents::InstanceExternalAuditEventDestination.active.exists?
      end

      private

      def destinations
        AuditEvents::InstanceExternalAuditEventDestination.active.limit(5)
      end
    end
  end
end
