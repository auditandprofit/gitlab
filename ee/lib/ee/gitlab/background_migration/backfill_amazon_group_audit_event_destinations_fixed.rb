# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module BackfillAmazonGroupAuditEventDestinationsFixed
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          operation_name :backfill_amazon_group_audit_event_destinations
          feature_category :audit_events
          scope_to ->(relation) do
            relation.where(stream_destination_id: nil)
          end
        end

        class AmazonS3Configuration < ::ApplicationRecord
          self.table_name = 'audit_events_amazon_s3_configurations'
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
            category: :aws,
            config: build_config(legacy_destination),
            legacy_destination_ref: legacy_destination.id,
            created_at: legacy_destination.created_at,
            updated_at: legacy_destination.updated_at,
            group_id: legacy_destination.namespace_id,
            encrypted_secret_token: legacy_destination.encrypted_secret_access_key,
            encrypted_secret_token_iv: legacy_destination.encrypted_secret_access_key_iv
          )
        end

        def build_config(legacy_destination)
          {
            'accessKeyXid' => legacy_destination.access_key_xid,
            'bucketName' => legacy_destination.bucket_name,
            'awsRegion' => legacy_destination.aws_region
          }
        end
      end
    end
  end
end
