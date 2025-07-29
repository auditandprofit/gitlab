# frozen_string_literal: true

module Mutations
  module AuditEvents
    module Group
      module EventTypeFilters
        class Create < Streaming::BaseEventTypeFilters::BaseCreate
          graphql_name 'AuditEventsGroupDestinationEventsAdd'
          authorize :admin_external_audit_events

          argument :destination_id, ::Types::GlobalIDType[::AuditEvents::Group::ExternalStreamingDestination],
            required: true,
            description: 'Destination id.'
        end
      end
    end
  end
end
