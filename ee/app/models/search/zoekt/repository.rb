# frozen_string_literal: true

module Search
  module Zoekt
    class Repository < ApplicationRecord
      include EachBatch

      INDEXABLE_STATES = %i[pending initializing ready].freeze
      SEARCHABLE_STATES = %i[ready].freeze

      self.table_name = 'zoekt_repositories'

      attribute :retries_left, default: 3

      belongs_to :zoekt_index, inverse_of: :zoekt_repositories, class_name: '::Search::Zoekt::Index'

      belongs_to :project, inverse_of: :zoekt_repositories, class_name: 'Project'

      has_many :tasks,
        foreign_key: :zoekt_repository_id, inverse_of: :zoekt_repository, class_name: '::Search::Zoekt::Task'

      before_validation :set_project_identifier

      validates_presence_of :zoekt_index_id, :project_identifier, :state, :schema_version

      validate :project_id_matches_project_identifier

      validates :project_identifier, uniqueness: {
        scope: :zoekt_index_id, message: 'violates unique constraint between [:zoekt_index_id, :project_identifier]'
      }

      enum :state, {
        pending: 0,
        initializing: 1,
        ready: 10,
        orphaned: 230,
        pending_deletion: 240,
        deleted: 250,
        failed: 255
      }

      scope :uncompleted, -> { where.not(state: %i[ready failed]) }

      scope :for_project_id, ->(project_id) { where(project_identifier: project_id) }

      scope :for_replica_id, ->(replica_id) { joins(:zoekt_index).where(zoekt_index: { zoekt_replica_id: replica_id }) }

      scope :should_be_marked_as_orphaned, -> { where(project_id: nil).where.not(state: :orphaned) }

      scope :should_be_deleted, -> do
        where(state: [:orphaned, :pending_deletion])
      end

      scope :should_be_indexed, -> do
        indexable.joins(zoekt_index: :node).where("#{table_name}.schema_version != #{Node.table_name}.schema_version")
          .or(pending)
      end

      scope :for_zoekt_indices, ->(indices) { where(zoekt_index: indices) }

      scope :indexable, -> { where(state: INDEXABLE_STATES) }
      scope :searchable, -> { where(state: SEARCHABLE_STATES) }

      # rubocop:disable Database/AvoidUsingPluckWithoutLimit -- Limit is on the call. It is temporary debugging code.
      # rubocop:disable Metrics/AbcSize -- Temporary debugging code.
      def self.create_bulk_tasks(task_type: :index_repo, perform_at: Time.zone.now)
        scope = self
        unless task_type.to_sym == :delete_repo
          # Only allow indexable repos for index_repo tasks
          scope = scope.indexable
        end

        log_data = { original_scope_id_state: scope.pluck(:id, :state) } if debug_log?(task_type)
        # Reject the repo_ids which already have the pending tasks for the given task_type
        scope = scope.where.not(
          id: Search::Zoekt::Task.pending.where(
            zoekt_repository_id: scope.select(:id), task_type: task_type
          ).select(:zoekt_repository_id)
        )

        log_data[:filtered_scope_id_state] = scope.pluck(:id, :state) if debug_log?(task_type)

        timestamp = Time.zone.now
        tasks = scope.includes(:zoekt_index).map do |zoekt_repo|
          Search::Zoekt::Task.new(
            zoekt_repository_id: zoekt_repo.id,
            zoekt_node_id: zoekt_repo.zoekt_index.zoekt_node_id,
            project_identifier: zoekt_repo.project_identifier,
            task_type: task_type,
            perform_at: perform_at,
            created_at: timestamp,
            updated_at: timestamp
          )
        end
        Search::Zoekt::Task.bulk_insert!(tasks)
        ids = tasks.map(&:zoekt_repository_id)
        deleted_ids = tasks.select(&:delete_repo?).map(&:zoekt_repository_id)
        active_ids = ids - deleted_ids
        unscoped.id_in(active_ids).pending.each_batch do |repos|
          repos.update_all(state: :initializing, updated_at: Time.current)
        end

        if debug_log?(task_type)
          log_data[:deleted_id_state_before_update] = unscoped.id_in(deleted_ids).pluck(:id, :state)
        end

        unscoped.id_in(deleted_ids).each_batch { |repos| repos.update_all(state: :deleted, updated_at: Time.current) }
        log_data[:deleted_id_state_final] = unscoped.id_in(deleted_ids).pluck(:id, :state) if debug_log?(task_type)
        return unless debug_log?(task_type)

        logger.info(log_data.merge(class: self, message: 'debug duplicate delete tasks'))
      end
      # rubocop:enable Database/AvoidUsingPluckWithoutLimit
      # rubocop:enable Metrics/AbcSize

      private

      def self.logger
        @logger ||= ::Search::Zoekt::Logger.build
      end

      def self.debug_log?(task_type)
        task_type == :delete_repo && Feature.enabled?(:zoekt_debug_delete_repo_logging, Feature.current_request)
      end

      def project_id_matches_project_identifier
        return unless project_id.present?
        return if project_id == project_identifier

        errors.add(:project_id, :invalid)
      end

      def set_project_identifier
        self.project_identifier ||= project_id
      end
    end
  end
end
