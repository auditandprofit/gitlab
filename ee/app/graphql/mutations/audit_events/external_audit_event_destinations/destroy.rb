# frozen_string_literal: true

module Mutations
  module AuditEvents
    module ExternalAuditEventDestinations
      class Destroy < Base
        graphql_name 'ExternalAuditEventDestinationDestroy'

        authorize :admin_external_audit_events

        argument :id, ::Types::GlobalIDType[::AuditEvents::ExternalAuditEventDestination],
          required: true,
          description: 'ID of external audit event destination to destroy.'

        def resolve(id:)
          destination = authorized_find!(id)
          paired_destination = destination.stream_destination

          if destination.destroy
            audit(destination, action: :destroy)

            if Feature.enabled?(:audit_events_external_destination_streamer_consolidation_refactor, destination.group)
              paired_destination&.destroy
            end
          end

          {
            external_audit_event_destination: nil,
            errors: []
          }
        end

        private

        def find_object(destination_gid)
          GitlabSchema.object_from_id(destination_gid, expected_type: ::AuditEvents::ExternalAuditEventDestination).sync
        end
      end
    end
  end
end
