# frozen_string_literal: true

module Ai
  module ActiveContext
    module Code
      class Repository < ApplicationRecord
        include PartitionedTable

        PARTITION_SIZE = 2_000_000
        METADATA_SIZE_LIMIT = 64.kilobytes

        self.table_name = 'p_ai_active_context_code_repositories'
        self.primary_key = :id

        partitioned_by :project_id, strategy: :int_range, partition_size: PARTITION_SIZE

        belongs_to :project
        belongs_to :enabled_namespace, class_name: 'Ai::ActiveContext::Code::EnabledNamespace', optional: true
        belongs_to :active_context_connection, class_name: 'Ai::ActiveContext::Connection',
          foreign_key: 'connection_id', optional: true, inverse_of: :repositories

        validates :project, presence: true
        validates :enabled_namespace, presence: true, on: :create
        validates :active_context_connection, presence: true, on: :create
        validates :state, presence: true
        validates :last_commit, length: { maximum: 64 }, allow_blank: true
        validates :connection_id, uniqueness: { scope: :project_id }, allow_nil: true
        validates :metadata, json_schema: {
          filename: 'ai_active_context_code_repositories_metadata',
          size_limit: METADATA_SIZE_LIMIT
        }

        before_create :set_last_commit

        enum :state, {
          pending: 0,
          code_indexing_in_progress: 5,
          embedding_indexing_in_progress: 6,
          ready: 10,
          pending_deletion: 240,
          deleted: 250,
          failed: 255
        }

        jsonb_accessor :metadata,
          initial_indexing_last_queued_item: :string,
          last_error: :string

        scope :for_connection_and_enabled_namespace, ->(connection, enabled_namespace) {
          where(connection_id: connection.id, enabled_namespace_id: enabled_namespace.id)
        }

        scope :with_active_connection, -> {
          joins(:active_context_connection).where(active_context_connection: { active: true })
        }

        scope :ready_with_active_connection, -> { ready.with_active_connection }

        private

        def set_last_commit
          self.last_commit = project.repository.blank_ref
        end
      end
    end
  end
end
