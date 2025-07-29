# frozen_string_literal: true

module Mutations
  module AuditEvents
    module Instance
      module AmazonS3Configurations
        class Delete < Base
          graphql_name 'AuditEventsInstanceAmazonS3ConfigurationDelete'

          argument :id, ::Types::GlobalIDType[::AuditEvents::Instance::AmazonS3Configuration],
            required: true,
            description: 'ID of the instance-level Amazon S3 configuration to delete.'

          def resolve(id:)
            config = authorized_find!(id: id)
            paired_destination = config.stream_destination

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
