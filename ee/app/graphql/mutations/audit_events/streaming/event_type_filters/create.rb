# frozen_string_literal: true

module Mutations
  module AuditEvents
    module Streaming
      module EventTypeFilters
        class Create < BaseEventTypeFilters::BaseCreate
          graphql_name 'AuditEventsStreamingDestinationEventsAdd'
          authorize :admin_external_audit_events

          argument :destination_id, ::Types::GlobalIDType[::AuditEvents::ExternalAuditEventDestination],
            required: true,
            description: 'Destination id.'
        end
      end
    end
  end
end
