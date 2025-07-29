# frozen_string_literal: true

module Mutations
  module AuditEvents
    module Streaming
      module InstanceEventTypeFilters
        class Create < BaseEventTypeFilters::BaseCreate
          graphql_name 'AuditEventsStreamingDestinationInstanceEventsAdd'
          authorize :admin_instance_external_audit_events

          argument :destination_id, ::Types::GlobalIDType[::AuditEvents::InstanceExternalAuditEventDestination],
            required: true,
            description: 'Destination id.'
        end
      end
    end
  end
end
