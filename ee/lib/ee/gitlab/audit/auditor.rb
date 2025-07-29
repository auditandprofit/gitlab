# frozen_string_literal: true

module EE
  module Gitlab
    module Audit
      module Auditor
        extend ::Gitlab::Utils::Override

        override :multiple_audit
        def multiple_audit
          ::Gitlab::Audit::EventQueue.begin!

          return_value = yield

          ::Gitlab::Audit::EventQueue.current
            .map { |audit| audit.is_a?(AuditEvent) ? audit : build_event(audit) }
            .then { |events| record(events) }

          return_value
        ensure
          ::Gitlab::Audit::EventQueue.end!
        end

        override :send_to_stream
        def send_to_stream(events)
          events.each do |event|
            event_name = name
            event.run_after_commit_or_now do
              event.stream_to_external_destinations(use_json: true, event_name: event_name)
            end
          end
        end

        override :audit_enabled?
        def audit_enabled?
          return true if super
          return true if ::License.feature_available?(:admin_audit_log)
          return true if ::License.feature_available?(:extended_audit_events)

          scope.respond_to?(:licensed_feature_available?) && scope.licensed_feature_available?(:audit_events)
        end

        override :log_events_and_stream
        def log_events_and_stream(events)
          log_authentication_event
          saved_events = log_to_database(events)
          new_audit_events = log_to_new_tables(saved_events, name)

          events_to_stream = determine_events_to_stream(new_audit_events, saved_events, events)
          log_to_file_and_stream(events_to_stream)
        end

        private

        # Determines which events should be streamed based on a priority order:
        # 1. New table events (if feature flag enabled for the entity)
        # 2. Original saved events (fallback if no feature-flagged new events)
        # 3. Original input events (fallback if nothing was saved)
        def determine_events_to_stream(new_audit_events, saved_events, original_events)
          if new_audit_events.present?
            filtered_new_events = filter_events_by_feature_flag(new_audit_events)
            filtered_new_events.presence || saved_events
          elsif saved_events.present?
            saved_events
          else
            original_events
          end
        end

        # Filters events based on the 'stream_audit_events_from_new_tables' feature flag
        # This controls which entities can use the new audit event tables
        def filter_events_by_feature_flag(events)
          events.select do |event|
            ::Gitlab::Audit::FeatureFlags.stream_from_new_tables?(event.entity)
          end
        end
      end
    end
  end
end
