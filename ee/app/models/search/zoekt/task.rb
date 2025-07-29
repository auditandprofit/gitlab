# frozen_string_literal: true

module Search
  module Zoekt
    class Task < ApplicationRecord
      include ::Search::Zoekt::Taskable

      self.table_name = 'zoekt_tasks'

      belongs_to :node, foreign_key: :zoekt_node_id, inverse_of: :tasks, class_name: '::Search::Zoekt::Node'
      belongs_to :zoekt_repository, inverse_of: :tasks, class_name: '::Search::Zoekt::Repository'

      before_validation :set_project_identifier

      scope :with_project, -> { includes(zoekt_repository: :project) }

      enum :task_type, {
        index_repo: 0,
        force_index_repo: 1,
        delete_repo: 50
      }

      def self.on_tasks_done(done_tasks)
        Repository.id_in(done_tasks.select(:zoekt_repository_id)).update_all(state: :ready, updated_at: Time.current)
      end

      def self.task_iterator
        scope = processing_queue.with_project.order(:perform_at, :id)
        Gitlab::Pagination::Keyset::Iterator.new(scope: scope)
      end

      def self.determine_task_state(task)
        return :valid if task.delete_repo?

        project = task.zoekt_repository&.project
        return :orphaned unless project

        zoekt_repository = task.zoekt_repository
        return :skipped unless Repository::INDEXABLE_STATES.include?(zoekt_repository.state.to_sym)

        # Mark tasks as done since we have nothing to index
        return :done unless project.repo_exists?

        :valid
      end

      def per_batch_unique_id
        project_identifier
      end

      private

      def set_project_identifier
        self.project_identifier ||= zoekt_repository&.project_identifier
      end
    end
  end
end
