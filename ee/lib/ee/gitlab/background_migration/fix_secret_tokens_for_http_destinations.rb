# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module FixSecretTokensForHttpDestinations
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        class LegacyGroupHttpDestination < ::ApplicationRecord
          self.table_name = 'audit_events_external_audit_event_destinations'
        end

        class GroupStreamingDestination < ::ApplicationRecord
          include ::Gitlab::EncryptedAttribute

          self.table_name = 'audit_events_group_external_streaming_destinations'
          enum :category, { http: 0, gcp: 1, aws: 2 }

          attr_encrypted :secret_token,
            mode: :per_attribute_iv,
            key: :db_key_base_32,
            algorithm: 'aes-256-gcm',
            encode: false,
            encode_iv: false

          belongs_to :group, class_name: '::Group'
        end

        prepended do
          operation_name :fix_secret_tokens_for_http_destinations
          feature_category :audit_events

          scope_to ->(relation) { relation.where(category: 0) } # HTTP only
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            process_http_destinations(sub_batch)
          end
        end

        private

        def process_http_destinations(sub_batch)
          sub_batch.each do |destination|
            streaming_destination = GroupStreamingDestination.find(destination.id)
            next unless http_destination_corrupted?(streaming_destination)

            fix_http_destination(streaming_destination)
          end
        end

        def http_destination_corrupted?(destination)
          destination.secret_token
          false
        rescue OpenSSL::Cipher::CipherError, ArgumentError
          true
        end

        def fix_http_destination(destination)
          original_token = get_original_http_token(destination)

          original_token = SecureRandom.base64(18) if original_token.blank?

          ::ApplicationRecord.transaction do
            temp_destination = GroupStreamingDestination.new
            temp_destination.secret_token = original_token

            properly_encrypted_token = temp_destination.encrypted_secret_token
            properly_encrypted_iv = temp_destination.encrypted_secret_token_iv

            destination.update_columns(
              encrypted_secret_token: properly_encrypted_token,
              encrypted_secret_token_iv: properly_encrypted_iv
            )
          end
        end

        def get_original_http_token(destination)
          return unless destination.legacy_destination_ref.present?

          legacy_destination = LegacyGroupHttpDestination.find_by(id: destination.legacy_destination_ref)
          token = legacy_destination&.verification_token

          token.presence
        end
      end
    end
  end
end
