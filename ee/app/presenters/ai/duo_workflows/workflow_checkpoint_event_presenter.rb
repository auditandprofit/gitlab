# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class WorkflowCheckpointEventPresenter < Gitlab::View::Presenter::Delegated
      presents ::Ai::DuoWorkflows::Checkpoint, as: :event

      def timestamp
        Time.parse(event.thread_ts)
      end

      def parent_timestamp
        Time.parse(event.parent_ts) if event.parent_ts
      end

      def workflow_status
        event.workflow.status
      end

      def workflow_goal
        Gitlab::AppLogger.info(
          workflow_gid: event.workflow.to_gid,
          checkpoint_ts: event.thread_ts,
          message: 'Serialising checkpoint'
        )
        event.workflow.goal
      end

      def workflow_definition
        event.workflow.workflow_definition
      end

      def execution_status
        graph_state = event.checkpoint.dig('channel_values', 'status')
        return graph_state unless graph_state.nil? || graph_state == 'Not Started'

        event.workflow.human_status_name.titleize
      end
    end
  end
end
