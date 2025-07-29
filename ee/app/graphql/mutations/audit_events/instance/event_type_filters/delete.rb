# frozen_string_literal: true

module Mutations
  module AuditEvents
    module Instance
      module EventTypeFilters
        class Delete < Streaming::BaseEventTypeFilters::BaseDestroy
          graphql_name 'AuditEventsInstanceDestinationEventsDelete'
          authorize :admin_instance_external_audit_events

          argument :destination_id, ::Types::GlobalIDType[::AuditEvents::Instance::ExternalStreamingDestination],
            required: true,
            description: 'Destination id.'
        end
      end
    end
  end
end
