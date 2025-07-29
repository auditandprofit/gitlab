# frozen_string_literal: true

module Search
  module Elastic
    class DeleteWorker
      include ApplicationWorker
      include Search::Worker
      prepend ::Geo::SkipSecondary

      sidekiq_options retry: 3
      data_consistency :delayed
      urgency :throttled
      idempotent!
      pause_control :advanced_search

      TASKS = {
        delete_project_work_items: ::Search::Elastic::Delete::ProjectWorkItemsService,
        delete_project_vulnerabilities: ::Search::Elastic::Delete::VulnerabilityService
      }.freeze

      def perform(options = {})
        return false unless Gitlab::CurrentSettings.elasticsearch_indexing?

        options = options.with_indifferent_access
        task = options[:task]
        return run_all_tasks(options) if task.to_sym == :all

        raise ArgumentError, "Unknown task: #{task.inspect}" unless TASKS.key?(task.to_sym)

        TASKS[task.to_sym].execute(options)
      end

      private

      def run_all_tasks(options)
        TASKS.each_key do |task|
          with_context(related_class: self.class) do
            self.class.perform_async(options.merge(task: task))
          end
        end
      end
    end
  end
end
