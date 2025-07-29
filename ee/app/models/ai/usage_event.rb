# frozen_string_literal: true

module Ai
  class UsageEvent < ApplicationRecord
    include EachBatch
    include ClickHouseModel
    include PartitionedTable

    self.table_name = "ai_usage_events"
    self.clickhouse_table_name = "ai_usage_events"

    partitioned_by :timestamp, strategy: :monthly, retain_for: 3.months
    self.primary_key = :id

    populate_sharding_key(:organization_id) { Gitlab::Current::Organization.new(user: user).organization&.id }

    belongs_to :user
    belongs_to :organization, class_name: 'Organizations::Organization'
    belongs_to :namespace, optional: true
    attribute :timestamp, :datetime, default: -> { DateTime.current }

    enum :event, Gitlab::Tracking::AiTracking.registered_events

    validates :timestamp, :user_id, :organization_id, presence: true
    validates :extras, json_schema: { filename: "ai_usage_event_extras", size_limit: 16.kilobytes }
    validate :validate_recent_timestamp, on: :create
    validate :validate_event_status, on: :create

    before_validation :floor_timestamp

    scope :with_namespace, -> { includes(:namespace) }
    scope :exclude_future_events, -> { where(arel_table[:timestamp].lteq(Time.current)) }
    scope :sort_by_timestamp_id, ->(dir: :desc) { order(timestamp: dir, id: dir) }

    # Keyset pagination optimization scopes
    scope :in_optimization_array_mapping_scope, ->(id_expression) { where(arel_table[:namespace_id].eq(id_expression)) }
    scope :in_optimization_finder_query, ->(timestamp_expression, id_expression) do
      where(arel_table[:timestamp].eq(timestamp_expression)).where(arel_table[:id].eq(id_expression))
    end

    def store_to_pg
      return false unless valid?

      Ai::UsageEventWriteBuffer.add(self.class.name, attributes.compact)
    end

    private

    def to_clickhouse_csv_row
      {
        event: self.class.events[event],
        # we round to 3 digits here to avoid floating number inconsistencies.
        # until https://gitlab.com/gitlab-org/gitlab/-/issues/527129
        # is resolved
        timestamp: Time.zone.parse(timestamp.as_json).to_f.round(3),
        user_id: user&.id,
        namespace_path: namespace&.traversal_path,
        extras: extras.to_json
      }
    end

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

    def validate_event_status
      return unless Gitlab::Tracking::AiTracking.deprecated_event?(event)

      errors.add(:event, _('is read-only'))
    end
  end
end
