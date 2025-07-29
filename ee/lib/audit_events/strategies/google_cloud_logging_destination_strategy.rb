# frozen_string_literal: true

module AuditEvents
  module Strategies
    class GoogleCloudLoggingDestinationStrategy < BaseGoogleCloudLoggingDestinationStrategy
      def streamable?
        group = audit_event.root_group_entity
        return false if group.nil?
        return false unless group.licensed_feature_available?(:external_audit_events)

        group.google_cloud_logging_configurations.active.exists?
      end

      private

      def destinations
        group = audit_event.root_group_entity
        return [] unless group.present?

        group.google_cloud_logging_configurations.active.limit(5)
      end
    end
  end
end
