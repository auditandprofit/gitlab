# frozen_string_literal: true

module Ai
  module ActiveContext
    module Code
      class RepositoryIndexService
        PROCESS_PENDING_LIMIT = 50

        def self.enqueue_pending_jobs
          ::Ai::ActiveContext::Code::Repository
            .pending.with_active_connection
            .limit(PROCESS_PENDING_LIMIT)
            .each do |repository|
              RepositoryIndexWorker.perform_async(repository.id)
            end
        end
      end
    end
  end
end
