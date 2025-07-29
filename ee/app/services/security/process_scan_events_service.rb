# frozen_string_literal: true

module Security
  class ProcessScanEventsService
    include Gitlab::InternalEventsTracking

    ScanEventNotInAllowListError = Class.new(StandardError)

    EVENT_NAME_ALLOW_LIST = %w[
      collect_sast_scan_metrics_from_pipeline
      collect_dast_scan_crawl_metrics_from_pipeline
      collect_dast_scan_ff_form_hashing_metrics_from_pipeline
      collect_dast_scan_form_metrics_from_pipeline
      collect_dast_scan_page_metrics_from_pipeline
    ].freeze

    def self.execute(pipeline)
      new(pipeline).execute
    end

    def initialize(pipeline)
      @pipeline = pipeline
    end

    def execute
      report_artifacts.each do |artifact|
        process_artifact(artifact)
      end
    end

    private

    attr_reader :pipeline

    def process_artifact(artifact)
      artifact.each_blob do |blob|
        json = parse_artifact_blob(artifact, blob)
        events = scan_observability_events_data(json)

        process_events(artifact, events)
      end
    end

    def parse_artifact_blob(artifact, blob)
      json = Gitlab::Json.parse(blob, symbolize_names: true, object_class: Hash)
      return unless json.is_a?(Hash)

      json
    rescue StandardError => e
      extra = {
        pipeline: pipeline,
        artifact: artifact
      }
      Gitlab::ErrorTracking.track_exception(e, extra)

      nil
    end

    def scan_observability_events_data(json)
      return unless json

      events = json.dig(:scan, :observability, :events)

      return unless events.is_a?(Array)

      events
    end

    def process_events(artifact, events)
      return unless events

      events.each do |event|
        process_event(artifact, event)
      end
    end

    def process_event(artifact, event)
      return unless event.key?(:event)

      name = event[:event]

      unless event_allowed?(name)
        Gitlab::ErrorTracking.track_and_raise_for_dev_exception(
          ScanEventNotInAllowListError.new("Event not in allow list '#{name}'"),
          event_name: name,
          pipeline: pipeline,
          artifact: artifact
        )

        return
      end

      track_event(event)
    end

    def event_allowed?(name)
      EVENT_NAME_ALLOW_LIST.include?(name)
    end

    def track_event(event)
      additional_properties = event.except(:event)

      track_internal_event(
        event[:event],
        user: pipeline.user,
        project: pipeline.project,
        additional_properties: additional_properties
      )
    end

    def report_artifacts
      pipeline.job_artifacts
              .security_reports
              .to_a
    end
  end
end
