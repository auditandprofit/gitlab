# frozen_string_literal: true

module AuditEvents
  class ExternalDestinationStreamer
    attr_reader :event_name, :audit_event

    STRATEGIES = [
      AuditEvents::Strategies::GroupExternalDestinationStrategy,
      AuditEvents::Strategies::InstanceExternalDestinationStrategy,
      AuditEvents::Strategies::GoogleCloudLoggingDestinationStrategy,
      AuditEvents::Strategies::Instance::GoogleCloudLoggingDestinationStrategy,
      AuditEvents::Strategies::AmazonS3DestinationStrategy,
      AuditEvents::Strategies::Instance::AmazonS3DestinationStrategy
    ].freeze

    def initialize(event_name, audit_event)
      @event_name = event_name
      @audit_event = audit_event
    end

    def stream_to_destinations
      if feature_flag_enabled? && streamers.any?(&:streamable?)
        streamers.each(&:execute)
      else
        streamable_strategies.each(&:execute)
      end
    end

    def streamable?
      if feature_flag_enabled?
        streamers.any?(&:streamable?) || streamable_strategies.any?
      else
        streamable_strategies.any?
      end
    end

    private

    def streamers
      @streamers ||= [
        AuditEvents::Streaming::Group::Streamer.new(event_name, audit_event),
        AuditEvents::Streaming::Instance::Streamer.new(event_name, audit_event)
      ]
    end

    def streamable_strategies
      @streamable_strategies ||= STRATEGIES.filter_map do |strategy|
        strategy_instance = strategy.new(event_name, audit_event)
        strategy_instance if strategy_instance.streamable?
      end
    end

    def feature_flag_enabled?
      Feature.enabled?(:audit_events_external_destination_streamer_consolidation_refactor, :instance)
    end
  end
end
