# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module BackfillGoogleGroupAuditEventDestinationsFixed
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          operation_name :backfill_google_group_audit_event_destinations
          feature_category :audit_events
          scope_to ->(relation) do
            relation.where(stream_destination_id: nil)
          end
        end

        class GoogleCloudLoggingConfiguration < ::ApplicationRecord
          self.table_name = 'audit_events_google_cloud_logging_configurations'
        end

        class ExternalStreamingDestination < ::ApplicationRecord
          self.table_name = 'audit_events_group_external_streaming_destinations'
          enum :category, { http: 0, gcp: 1, aws: 2 }
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            process_batch(sub_batch)
          end
        end

        private

        def process_batch(sub_batch)
          sub_batch.each do |legacy_destination|
            ApplicationRecord.transaction do
              destination = create_streaming_destination(legacy_destination)
              next unless destination

              legacy_destination.update!(stream_destination_id: destination.id)
            end
          end
        end

        def create_streaming_destination(legacy_destination)
          ExternalStreamingDestination.create!(
            name: legacy_destination.name,
            category: :gcp,
            config: build_config(legacy_destination),
            legacy_destination_ref: legacy_destination.id,
            group_id: legacy_destination.namespace_id,
            encrypted_secret_token: legacy_destination.encrypted_private_key,
            encrypted_secret_token_iv: legacy_destination.encrypted_private_key_iv,
            created_at: legacy_destination.created_at,
            updated_at: legacy_destination.updated_at
          )
        end

        def build_config(legacy_destination)
          {
            'googleProjectIdName' => legacy_destination.google_project_id_name,
            'logIdName' => legacy_destination.log_id_name || 'audit-events',
            'clientEmail' => legacy_destination.client_email
          }
        end
      end
    end
  end
end
