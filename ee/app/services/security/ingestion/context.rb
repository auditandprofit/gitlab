# frozen_string_literal: true

module Security
  module Ingestion
    class Context
      def run_after_sec_commit(&block)
        raise ArgumentError, 'block is required' unless block

        sec_tasks_queue << block
      end

      def run_sec_after_commit_tasks
        sec_tasks_queue.each(&:call)
      end

      private

      def sec_tasks_queue
        @sec_tasks_queue ||= []
      end
    end
  end
end
