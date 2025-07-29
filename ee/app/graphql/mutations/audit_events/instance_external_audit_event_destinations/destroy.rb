# frozen_string_literal: true

module Mutations
  module AuditEvents
    module InstanceExternalAuditEventDestinations
      class Destroy < Base
        graphql_name 'InstanceExternalAuditEventDestinationDestroy'

        authorize :admin_instance_external_audit_events

        argument :id, ::Types::GlobalIDType[::AuditEvents::InstanceExternalAuditEventDestination],
          required: true,
          description: 'ID of the external instance audit event destination to destroy.'

        def resolve(id:)
          destination = find_object(id)
          paired_destination = destination.stream_destination

          if destination.destroy
            audit(destination, action: :destroy)

            if Feature.enabled?(:audit_events_external_destination_streamer_consolidation_refactor,
              :instance)
              paired_destination&.destroy
            end
          end

          {
            instance_external_audit_event_destination: nil,
            errors: []
          }
        end
      end
    end
  end
end
