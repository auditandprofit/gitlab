# frozen_string_literal: true

module AuditEvents
  module Streaming
    class BaseStreamer
      include Gitlab::InternalEventsTracking

      INTERNAL_EVENTS = %w[delete_epic delete_issue delete_merge_request delete_work_item].freeze
      STREAMABLE_NOT_IMPLEMENTED_MESSAGE = 'Subclasses must implement the `streamable?` method'
      DESTINATIONS_NOT_IMPLEMENTED_MESSAGE = 'Subclasses must implement the `destinations` method'
      STREAMER_CATEGORY_NOT_FOUND_MESSAGE = 'Streamer class for category not found'

      attr_reader :event_type, :audit_event

      STREAMER_DESTINATIONS = {
        'aws' => AuditEvents::Streaming::Destinations::AmazonS3StreamDestination,
        'gcp' => AuditEvents::Streaming::Destinations::GoogleCloudLoggingStreamDestination,
        'http' => AuditEvents::Streaming::Destinations::HttpStreamDestination
      }.freeze

      def initialize(event_type, audit_event)
        @event_type = event_type
        @audit_event = audit_event
      end

      def streamable?
        raise NotImplementedError, _(STREAMABLE_NOT_IMPLEMENTED_MESSAGE)
      end

      def execute
        return unless streamable?

        destinations.each do |destination|
          track_and_stream(destination)
        end
      end

      private

      def destinations
        raise NotImplementedError, _(DESTINATIONS_NOT_IMPLEMENTED_MESSAGE)
      end

      def track_and_stream(destination)
        track_audit_event
        stream_to_destination(destination)
      rescue StandardError => e
        Gitlab::ErrorTracking.track_exception(e)
      end

      def stream_to_destination(destination)
        streamer_cls = STREAMER_DESTINATIONS[destination.category]

        raise ArgumentError, _(STREAMER_CATEGORY_NOT_FOUND_MESSAGE) unless streamer_cls

        streamer = streamer_cls.new(event_type, audit_event, destination)
        streamer.stream
      end

      def track_audit_event
        return unless event_type.in?(INTERNAL_EVENTS)

        track_internal_event("trigger_audit_event", additional_properties: { label: event_type })
      end
    end
  end
end
