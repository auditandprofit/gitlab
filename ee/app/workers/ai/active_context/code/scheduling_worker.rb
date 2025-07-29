# frozen_string_literal: true

# rubocop: disable Sidekiq/EnforceDatabaseHealthSignalDeferral -- database tables don't exist yet https://gitlab.com/gitlab-org/gitlab/-/issues/536221

module Ai
  module ActiveContext
    module Code
      class SchedulingWorker
        include ApplicationWorker
        include CronjobQueue
        prepend ::Geo::SkipSecondary

        feature_category :global_search
        deduplicate :until_executed
        data_consistency :sticky
        idempotent!
        urgency :low
        loggable_arguments 0

        def perform(task = nil)
          return false unless ::Ai::ActiveContext::Collections::Code.indexing?

          return initiate if task.nil?

          SchedulingService.execute(task)
        end

        private

        def initiate
          SchedulingService::TASKS.each do |task|
            with_context(related_class: self.class) { self.class.perform_async(task.first.to_s) }
          end
        end
      end
    end
  end
end

# rubocop: enable Sidekiq/EnforceDatabaseHealthSignalDeferral
