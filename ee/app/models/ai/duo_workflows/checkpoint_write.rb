# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class CheckpointWrite < ::ApplicationRecord
      include ::Ai::DuoWorkflows::SyncWorkflowAttributes
      include BulkInsertSafe

      CHECKPOINT_WRITES_LIMIT = 10000

      self.table_name = :duo_workflows_checkpoint_writes

      belongs_to :workflow, class_name: 'Ai::DuoWorkflows::Workflow'
      belongs_to :project, optional: true
      belongs_to :namespace, optional: true
      belongs_to :checkpoint, ->(write) { where(workflow_id: write.workflow_id) },
        foreign_key: :thread_ts, primary_key: :thread_ts, inverse_of: :checkpoint_writes, optional: true

      validates :workflow, presence: true
      validates :thread_ts, presence: true
      validates :task, presence: true
      validates :idx, presence: true
      validates :channel, presence: true
      validates :write_type, presence: true
      validates :data, length: { maximum: CHECKPOINT_WRITES_LIMIT }
    end
  end
end
