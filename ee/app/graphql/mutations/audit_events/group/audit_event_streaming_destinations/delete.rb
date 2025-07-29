# frozen_string_literal: true

module Mutations
  module AuditEvents
    module Group
      module AuditEventStreamingDestinations
        class Delete < Base
          graphql_name 'GroupAuditEventStreamingDestinationsDelete'

          argument :id, ::Types::GlobalIDType[::AuditEvents::Group::ExternalStreamingDestination],
            required: true,
            description: 'ID of the audit events external streaming destination to delete.'

          def resolve(id:)
            config = authorized_find!(id: id)
            paired_destination = config.legacy_destination
            if config.destroy
              audit(config, action: :deleted)

              if Feature.enabled?(:audit_events_external_destination_streamer_consolidation_refactor,
                :instance)
                paired_destination&.destroy
              end
            end

            { errors: Array(config.errors) }
          end
        end
      end
    end
  end
end
