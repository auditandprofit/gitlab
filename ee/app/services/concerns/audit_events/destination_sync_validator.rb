# frozen_string_literal: true

module AuditEvents
  module DestinationSyncValidator
    def legacy_destination_sync_enabled?(legacy_destination_model, is_instance)
      entity = is_instance ? :instance : legacy_destination_model.group
      Feature.enabled?(:audit_events_external_destination_streamer_consolidation_refactor,
        entity)
    end

    def stream_destination_sync_enabled?(stream_destination_model)
      entity = stream_destination_model.instance_level? ? :instance : stream_destination_model.group
      Feature.enabled?(:audit_events_external_destination_streamer_consolidation_refactor, entity)
    end

    def should_sync_http?(destination)
      is_legacy = destination.respond_to?(:stream_destination_id)

      if is_legacy
        return false unless legacy_destination_sync_enabled?(destination, destination.instance_level?)
        return false unless destination.stream_destination_id.present?

        stream_destination = destination.stream_destination
      else
        return false unless stream_destination_sync_enabled?(destination)
        return false unless destination.legacy_destination_ref.present?

        stream_destination = destination
      end

      return false unless stream_destination.http?

      true
    end
  end
end
