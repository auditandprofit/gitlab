# frozen_string_literal: true

module AuditEvents
  module ExternallyStreamable
    extend ActiveSupport::Concern

    MAXIMUM_NAMESPACE_FILTER_COUNT = 5
    MAXIMUM_DESTINATIONS_PER_ENTITY = 5
    STREAMING_TOKEN_HEADER_KEY = "X-Gitlab-Event-Streaming-Token"

    included do
      include Gitlab::EncryptedAttribute

      before_validation :ensure_config_is_hash
      before_validation :assign_default_name
      before_validation :assign_secret_token_for_http
      before_validation :assign_default_log_id, if: :gcp?
      before_validation :remove_empty_headers_from_config
      before_validation :ensure_protected_header_not_modified

      enum :category, {
        http: 0,
        gcp: 1,
        aws: 2
      }

      validates :name, length: { maximum: 72 }
      validates :category, presence: true

      validate :config_is_properly_formatted

      validates :config, presence: true,
        json_schema: { filename: 'audit_events_http_external_streaming_destination_config' }, if: :http?
      validates :config, presence: true,
        json_schema: { filename: 'audit_events_aws_external_streaming_destination_config' }, if: :aws?
      validates :config, presence: true,
        json_schema: { filename: 'audit_events_gcp_external_streaming_destination_config' }, if: :gcp?
      validates :secret_token, presence: true, unless: :http?

      validates_with AuditEvents::HttpDestinationValidator, if: :http?
      validates_with AuditEvents::AwsDestinationValidator, if: :aws?
      validates_with AuditEvents::GcpDestinationValidator, if: :gcp?
      validate :no_more_than_5_namespace_filters?

      attr_encrypted :secret_token,
        mode: :per_attribute_iv,
        key: :db_key_base_32,
        algorithm: 'aes-256-gcm',
        encode: false,
        encode_iv: false

      scope :configs_of_parent, ->(record_id, category) {
        id_not_in(record_id).where(category: category).limit(MAXIMUM_DESTINATIONS_PER_ENTITY).pluck(:config)
      }

      def config
        stored_config = super

        return stored_config unless stored_config.is_a?(String)

        begin
          ::Gitlab::Json.parse(stored_config)
        rescue JSON::ParserError
          stored_config
        end
      end

      def headers_hash
        return {} unless http?

        (config['headers'] || {})
          .select { |_, h| h['active'] == true }
          .transform_values { |h| h['value'] }
          .merge(STREAMING_TOKEN_HEADER_KEY => secret_token)
      end

      private

      def config_is_properly_formatted
        return unless config_changed? || new_record?

        return if config.is_a?(Hash)

        errors.add(:config, "must be a hash")
      end

      def ensure_config_is_hash
        return unless config.is_a?(String)

        begin
          self.config = ::Gitlab::Json.parse(config)
        rescue JSON::ParserError
          # Let validation handle this
        end
      end

      def assign_default_name
        self.name ||= "Destination_#{SecureRandom.uuid}"
      end

      def no_more_than_5_namespace_filters?
        return unless namespace_filters.count > MAXIMUM_NAMESPACE_FILTER_COUNT

        errors.add(:namespace_filters,
          format(_("are limited to %{max_count} per destination"), max_count: MAXIMUM_NAMESPACE_FILTER_COUNT))
      end

      def assign_default_log_id
        config["logIdName"] = "audit-events" if config["logIdName"].blank?
      end

      def assign_secret_token_for_http
        return unless http?

        self.secret_token ||= SecureRandom.base64(18)
      end

      def sync_helper?
        (new_record? && legacy_destination_ref.present?) || (persisted? && changes.key?('secret_token'))
      end

      def ensure_protected_header_not_modified
        return unless config_changed?

        old_config = config_was || {}
        new_config = config || {}

        old_headers = old_config['headers'] || {}
        new_headers = new_config['headers'] || {}

        old_headers_upcase = old_headers.transform_keys(&:upcase)
        new_headers_upcase = new_headers.transform_keys(&:upcase)
        protected_key_upcase = STREAMING_TOKEN_HEADER_KEY.upcase

        return unless !old_headers_upcase.key?(protected_key_upcase) && new_headers_upcase.key?(protected_key_upcase)
        return if sync_helper?

        errors.add(:config, "headers cannot contain #{STREAMING_TOKEN_HEADER_KEY}")
      end

      def remove_empty_headers_from_config
        return unless http?
        return unless config.is_a?(Hash)

        config.delete('headers') if config['headers'] == {}
      end
    end
  end
end
