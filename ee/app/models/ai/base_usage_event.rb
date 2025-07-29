# frozen_string_literal: true

module Ai
  module BaseUsageEvent
    extend ActiveSupport::Concern
    include ClickHouseModel
    include PartitionedTable

    class_methods do
      def related_event?(event_name)
        events.key?(event_name)
      end

      def payload_attributes
        schema_validator = validators_on(:payload).detect { |v| v.is_a?(JsonSchemaValidator) }
        schema_validator.schema.value['properties'].keys
      end

      def permitted_attributes
        %w[user user_id organization organization_id personal_namespace_id namespace_path timestamp event].freeze
      end
    end

    included do
      belongs_to :user

      attribute :timestamp, :datetime, default: -> { DateTime.current }

      partitioned_by :timestamp, strategy: :monthly, retain_for: 3.months
      self.primary_key = :id

      validates :timestamp, :user_id, presence: true
      validate :validate_recent_timestamp, on: :create

      before_validation :floor_timestamp

      validates :payload, json_schema: { filename: "#{model_name.singular}_payload", size_limit: 16.kilobytes },
        allow_blank: true
    end

    def to_clickhouse_csv_row
      {
        event: self.class.events[event],
        # we round to 3 digits here to avoid floating number inconsistencies.
        # until https://gitlab.com/gitlab-org/gitlab/-/issues/527129
        # is resolved
        timestamp: Time.zone.parse(timestamp.as_json).to_f.round(3),
        user_id: user&.id,
        namespace_path: namespace_path
      }
    end

    # Default to empty hash if payload is empty
    def payload
      super || {}
    end

    def store_to_pg
      return false unless valid?

      Ai::UsageEventWriteBuffer.add(self.class.name, attributes.compact)
    end

    private

    def floor_timestamp
      # we floor to 3 digits here to match current JSON rounding used in Write Buffers.
      # That creates consistency between PG and CH until https://gitlab.com/gitlab-org/gitlab/-/issues/527129
      # is resolved
      self.timestamp = timestamp&.floor(3)
    end

    def validate_recent_timestamp
      return unless timestamp && timestamp < self.class.partitioning_strategy.retain_for.ago

      errors.add(:timestamp, _('must be 3 months old at the most'))
    end
  end
end
