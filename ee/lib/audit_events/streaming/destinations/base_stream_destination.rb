# frozen_string_literal: true

module AuditEvents
  module Streaming
    module Destinations
      class BaseStreamDestination
        REQUEST_BODY_SIZE_LIMIT = 25.megabytes
        STREAM_ERROR_MESSAGE = 'Subclasses must implement the `stream` method'
        EVENT_TYPE_HEADER_KEY = "X-Gitlab-Audit-Event-Type"

        attr_reader :event_type, :audit_event, :destination

        def initialize(event_type, audit_event, destination)
          @event_type = event_type
          @audit_event = audit_event
          @destination = destination
        end

        def stream
          raise NotImplementedError, _(STREAM_ERROR_MESSAGE)
        end

        protected

        def request_body
          body = @audit_event.as_json
          body[:event_type] = @event_type
          # We want to have uuid for stream only audit events also and in this case audit_event's id is blank.
          # so we override it with `SecureRandom.uuid`
          body["id"] = SecureRandom.uuid if @audit_event.id.blank?
          Gitlab::Json::LimitedEncoder.encode(body, limit: REQUEST_BODY_SIZE_LIMIT)
        end
      end
    end
  end
end
