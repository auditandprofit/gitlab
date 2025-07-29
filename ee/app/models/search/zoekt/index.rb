# frozen_string_literal: true

module Search
  module Zoekt
    class Index < ApplicationRecord
      self.table_name = 'zoekt_indices'
      include EachBatch
      include NamespaceValidateable

      DEFAULT_USED_STORAGE_BYTES = 1.kilobyte.freeze
      EVICTION_STATES = %i[evicted pending_eviction].freeze
      SEARCHEABLE_STATES = %i[ready].freeze
      SHOULD_BE_DELETED_STATES = %i[orphaned pending_deletion].freeze
      STORAGE_IDEAL_PERCENT_USED = 0.6
      STORAGE_LOW_WATERMARK = 0.70
      STORAGE_HIGH_WATERMARK = 0.75
      STORAGE_CRITICAL_WATERMARK = 0.80

      belongs_to :zoekt_enabled_namespace, inverse_of: :indices, class_name: '::Search::Zoekt::EnabledNamespace'
      belongs_to :node, foreign_key: :zoekt_node_id, inverse_of: :indices, class_name: '::Search::Zoekt::Node'
      belongs_to :replica, foreign_key: :zoekt_replica_id, inverse_of: :indices

      has_many :zoekt_repositories, foreign_key: :zoekt_index_id, inverse_of: :zoekt_index,
        class_name: '::Search::Zoekt::Repository'

      validates :metadata, json_schema: { filename: 'zoekt_indices_metadata' }

      enum :state, {
        pending: 0,
        in_progress: 1,
        initializing: 2,
        ready: 10,
        reallocating: 20,
        pending_eviction: 220,
        evicted: 225,
        orphaned: 230,
        pending_deletion: 240
      }

      enum :watermark_level, {
        healthy: 0,
        overprovisioned: 10,
        low_watermark_exceeded: 30,
        high_watermark_exceeded: 60,
        critical_watermark_exceeded: 90
      }

      scope :for_node, ->(node) do
        where(node: node)
      end

      scope :for_replica, ->(ids) { where(replica: ids) }
      scope :for_root_namespace_id, ->(root_namespace_id) do
        where(namespace_id: root_namespace_id).where.not(zoekt_enabled_namespace_id: nil)
      end

      scope :pre_ready, -> { where(state: %i[pending in_progress initializing]) }

      scope :searchable, -> do
        where(state: SEARCHEABLE_STATES)
          .joins(:zoekt_enabled_namespace)
          .where(zoekt_enabled_namespace: { search: true })
      end

      scope :for_root_namespace_id_with_search_enabled, ->(root_namespace_id) do
        for_root_namespace_id(root_namespace_id)
          .joins(:zoekt_enabled_namespace)
          .where(zoekt_enabled_namespace: { search: true })
      end

      scope :with_all_finished_repositories, -> do
        where_not_exists(Repository.uncompleted.where(Repository.arel_table[:zoekt_index_id].eq(Index.arel_table[:id])))
      end

      scope :ordered, -> { order(:id) }
      scope :ordered_by_used_storage_updated_at, -> { order(:used_storage_bytes_updated_at) }
      scope :preload_zoekt_enabled_namespace_and_namespace, -> { includes(zoekt_enabled_namespace: :namespace) }
      scope :preload_node, -> { includes(:node) }
      scope :with_stale_used_storage_bytes_updated_at, -> { where('last_indexed_at >= used_storage_bytes_updated_at') }
      scope :with_latest_used_storage_bytes_updated_at, -> { where('last_indexed_at < used_storage_bytes_updated_at') }
      scope :negative_reserved_storage_bytes, -> { where('reserved_storage_bytes < 0') }
      scope :should_be_marked_as_orphaned, -> do
        where(zoekt_enabled_namespace: nil).or(where(replica: nil)).where.not(state: SHOULD_BE_DELETED_STATES)
      end

      scope :should_be_pending_eviction, -> do
        critical_watermark_exceeded.where.not(state: EVICTION_STATES + SHOULD_BE_DELETED_STATES)
      end

      scope :should_be_deleted, -> do
        where(state: SHOULD_BE_DELETED_STATES)
      end

      scope :with_mismatched_watermark_levels, -> do
        where <<~SQL.squish
          CASE
            WHEN (used_storage_bytes / NULLIF(reserved_storage_bytes, 0)::float) < #{STORAGE_IDEAL_PERCENT_USED}
              THEN #{watermark_levels[:overprovisioned]}
            WHEN (used_storage_bytes / NULLIF(reserved_storage_bytes, 0)::float) < #{STORAGE_LOW_WATERMARK}
              THEN #{watermark_levels[:healthy]}
            WHEN (used_storage_bytes / NULLIF(reserved_storage_bytes, 0)::float) < #{STORAGE_HIGH_WATERMARK}
              THEN #{watermark_levels[:low_watermark_exceeded]}
            WHEN (used_storage_bytes / NULLIF(reserved_storage_bytes, 0)::float) < #{STORAGE_CRITICAL_WATERMARK}
              THEN #{watermark_levels[:high_watermark_exceeded]}
            ELSE #{watermark_levels[:critical_watermark_exceeded]}
          END != watermark_level
        SQL
      end

      def update_storage_bytes_and_watermark_level!(skip_used_storage_bytes: false)
        refresh_used_storage_bytes unless skip_used_storage_bytes
        refresh_reserved_storage_bytes
        self.watermark_level = appropriate_watermark_level
        save!
      end

      def free_storage_bytes
        reserved_storage_bytes.to_i - used_storage_bytes
      end

      def should_be_deleted?
        SHOULD_BE_DELETED_STATES.include? state.to_sym
      end

      def find_or_create_repository_by_project!(identifier, project)
        zoekt_repositories.find_or_create_by!(project_identifier: identifier, project: project)
      end

      def project_namespace_id_exhaustive_range
        case [metadata['project_namespace_id_from'], metadata['project_namespace_id_to']]
        in [nil, nil]
          nil
        in [nil, id_to]
          (..id_to)
        in [id_from, nil]
          (id_from..)
        in [id_from, id_to]
          id_from..id_to
        end
      end

      def appropriate_watermark_level
        case storage_percent_used
        when 0...STORAGE_IDEAL_PERCENT_USED then :overprovisioned
        when STORAGE_IDEAL_PERCENT_USED...STORAGE_LOW_WATERMARK then :healthy
        when STORAGE_LOW_WATERMARK...STORAGE_HIGH_WATERMARK then :low_watermark_exceeded
        when STORAGE_HIGH_WATERMARK...STORAGE_CRITICAL_WATERMARK then :high_watermark_exceeded
        else
          :critical_watermark_exceeded
        end
      end

      private

      def storage_percent_used
        used_storage_bytes / reserved_storage_bytes.to_f
      end

      def refresh_used_storage_bytes
        sum_for_index = zoekt_repositories.sum(:size_bytes)
        self.used_storage_bytes = sum_for_index == 0 ? DEFAULT_USED_STORAGE_BYTES : sum_for_index
        self.used_storage_bytes_updated_at = Time.zone.now
      end

      # Allows the reduction of reserved_storage_bytes only if index is ready.
      # Always allows the possible expansion of reserved_storage_bytes.
      def refresh_reserved_storage_bytes
        # This number of bytes will put the index as the ideal storage utilization.
        ideal_reserved_storage_bytes = (used_storage_bytes / STORAGE_IDEAL_PERCENT_USED).to_i

        # Note: this will also **decrease** the reservation if the total needed is now lower.
        new_reserved_bytes = if ideal_reserved_storage_bytes > reserved_storage_bytes
                               claim_reserved_storage_bytes_from_node(ideal_reserved_storage_bytes)
                             else
                               ideal_reserved_storage_bytes
                             end

        # Do not update reserved_storage_bytes if new_reserved_bytes is less and index is not ready.
        # Case could be that index is initializing and used_storage_bytes is just building up. So do not rely on it.
        return if (new_reserved_bytes < reserved_storage_bytes) && !ready?

        self.reserved_storage_bytes = new_reserved_bytes
      end

      # Return existing reserved_storage_bytes if node does not have any unclaimed_storage_bytes.
      # If node has full availability of storage bytes asked by index, it will return the storage bytes asked by index.
      # If node has not full availability, node will return the maximum it can give to the index.
      def claim_reserved_storage_bytes_from_node(ideal_reserved_storage_bytes)
        # return existing reserved_storage_bytes, can not do anything as there is no unclaimed storage in node.
        return reserved_storage_bytes if node.unclaimed_storage_bytes <= 0

        max_reservable_storage_bytes = node.unclaimed_storage_bytes + reserved_storage_bytes.to_i
        # In case there is more requested bytes than available on the node,
        # we reserve the minimum amount that we have available.
        [ideal_reserved_storage_bytes, max_reservable_storage_bytes].min
      end
    end
  end
end
