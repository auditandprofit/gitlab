# frozen_string_literal: true

module AuditEvents
  module Strategies
    class ExternalDestinationStrategy
      include Gitlab::InternalEventsTracking

      attr_reader :audit_operation, :audit_event

      EVENT_TYPE_HEADER_KEY = "X-Gitlab-Audit-Event-Type"
      REQUEST_BODY_SIZE_LIMIT = 25.megabytes
      STREAMABLE_ERROR_MESSAGE = 'Subclasses must implement the `streamable?` method'
      DESTINATIONS_ERROR_MESSAGE = 'Subclasses must implement the `destinations` method'
      INTERNAL_EVENTS = %w[delete_epic delete_issue delete_merge_request delete_work_item].freeze

      def initialize(audit_operation, audit_event)
        @audit_operation = audit_operation
        @audit_event = audit_event
      end

      def streamable?
        raise NotImplementedError, STREAMABLE_ERROR_MESSAGE
      end

      def execute
        return unless streamable?

        destinations.each do |destination|
          track_and_stream(destination) if destination.allowed_to_stream?(audit_operation, audit_event)
        end
      end

      private

      def destinations
        raise NotImplementedError, DESTINATIONS_ERROR_MESSAGE
      end

      def track_and_stream(destination)
        headers = build_headers(destination)

        track_audit_event

        Gitlab::HTTP.post(
          destination.destination_url,
          body: request_body,
          headers: headers,
          **::AuditEvents::HttpTimeoutConfig::DEFAULT
        )
      rescue URI::InvalidURIError => e
        Gitlab::ErrorTracking.log_exception(e)
      rescue *Gitlab::HTTP::HTTP_ERRORS
      end

      def build_headers(destination)
        headers = destination.headers_hash
        headers[EVENT_TYPE_HEADER_KEY] = audit_operation if audit_operation.present?
        headers
      end

      def track_audit_event
        return unless audit_operation.in?(INTERNAL_EVENTS)

        track_internal_event("trigger_audit_event", additional_properties: { label: audit_operation })
      end

      def request_body
        body = audit_event.as_json
        body[:event_type] = audit_operation
        # We want to have uuid for stream only audit events also and in this case audit_event's id is blank.
        # so we override it with `SecureRandom.uuid`
        body["id"] = SecureRandom.uuid if audit_event.id.blank?
        Gitlab::Json::LimitedEncoder.encode(body, limit: REQUEST_BODY_SIZE_LIMIT)
      end
    end
  end
end
