# frozen_string_literal: true

module Ai
  module DuoWorkflows
    CHECKPOINT_RETENTION_DAYS = 30

    class Checkpoint < ::ApplicationRecord
      include ::Ai::DuoWorkflows::SyncWorkflowAttributes
      include PartitionedTable

      partitioned_by :created_at, strategy: :daily, retain_for: CHECKPOINT_RETENTION_DAYS.days
      self.table_name = :p_duo_workflows_checkpoints

      belongs_to :workflow, class_name: 'Ai::DuoWorkflows::Workflow'
      belongs_to :project, optional: true
      belongs_to :namespace, optional: true

      # checkpoint_writes can be created independently on checkpoints by langgraph so checkpoints and checkpoint_writes
      # are associated only by langgraph's thread_ts
      has_many :checkpoint_writes, ->(checkpoint) { where(workflow_id: checkpoint.workflow_id) },
        foreign_key: :thread_ts, primary_key: :thread_ts, inverse_of: :checkpoint

      validates :thread_ts, presence: true
      validates :checkpoint, presence: true
      validates :metadata, presence: true

      after_save :touch_workflow

      scope :ordered_with_writes, -> { includes(:checkpoint_writes).order(thread_ts: :desc) }
      scope :with_checkpoint_writes, -> { includes(:checkpoint_writes) }

      # Single ID lookups are possible due to database trigger
      # [id, created_at] being composite id due to partitioning
      def self.find(*args)
        if args.length == 1 && !args[0].is_a?(Array)
          find_by_id(args[0])
        else
          super
        end
      end

      def to_global_id(_options = {})
        GlobalID.new(::Gitlab::GlobalId.build(self, id: id.first))
      end
      alias_method :to_gid, :to_global_id

      private

      def touch_workflow
        workflow.touch
      end
    end
  end
end
