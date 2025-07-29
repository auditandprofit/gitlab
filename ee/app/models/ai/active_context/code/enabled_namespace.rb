# frozen_string_literal: true

module Ai
  module ActiveContext
    module Code
      class EnabledNamespace < ApplicationRecord
        include PartitionedTable

        PARTITION_SIZE = 2_000_000
        METADATA_SIZE_LIMIT = 64.kilobytes

        self.table_name = 'p_ai_active_context_code_enabled_namespaces'
        self.primary_key = :id

        partitioned_by :namespace_id, strategy: :int_range, partition_size: PARTITION_SIZE

        belongs_to :namespace
        belongs_to :active_context_connection, class_name: 'Ai::ActiveContext::Connection',
          foreign_key: 'connection_id', inverse_of: :enabled_namespaces

        has_many :repositories,
          class_name: 'Ai::ActiveContext::Code::Repository', inverse_of: :enabled_namespace

        validates :namespace, presence: true
        validates :active_context_connection, presence: true
        validates :state, presence: true
        validates :connection_id, uniqueness: { scope: :namespace_id }
        validate :valid_namespace
        validates :metadata, json_schema: {
          filename: 'ai_active_context_code_enabled_namespaces_metadata',
          size_limit: METADATA_SIZE_LIMIT
        }

        enum :state, {
          pending: 0,
          ready: 10
        }

        scope :namespace_id_in, ->(namespace_ids) { where(namespace_id: namespace_ids) }
        scope :with_active_connection, -> {
          joins(:active_context_connection).where(active_context_connection: { active: true })
        }

        private

        def valid_namespace
          return if namespace && namespace.root? && namespace.group_namespace?

          errors.add(:namespace, _('must be a root group.'))
        end
      end
    end
  end
end
