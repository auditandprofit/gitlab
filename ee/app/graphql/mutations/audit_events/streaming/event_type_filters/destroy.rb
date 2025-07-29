# frozen_string_literal: true

module Mutations
  module AuditEvents
    module Streaming
      module EventTypeFilters
        class Destroy < BaseEventTypeFilters::BaseDestroy
          graphql_name 'AuditEventsStreamingDestinationEventsRemove'

          authorize :admin_external_audit_events

          argument :destination_id, ::Types::GlobalIDType[::AuditEvents::ExternalAuditEventDestination],
            required: true,
            description: 'Destination id.'
        end
      end
    end
  end
end
