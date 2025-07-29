# frozen_string_literal: true

module Security
  module Ingestion
    class IngestSliceBaseService
      include Gitlab::Utils::StrongMemoize

      def self.execute(pipeline, finding_maps)
        new(pipeline, finding_maps).execute
      end

      def initialize(pipeline, finding_maps)
        @pipeline = pipeline
        @finding_maps = finding_maps
      end

      def execute
        run_tasks_in_sec_db
        context.run_sec_after_commit_tasks
        run_tasks_in_main_db

        update_elasticsearch

        vulnerability_ids
      end

      private

      attr_reader :pipeline, :finding_maps

      def run_tasks_in_sec_db
        ::SecApplicationRecord.transaction do
          project = pipeline&.project

          feature_enabled = Feature.enabled?(:turn_off_vulnerability_read_create_db_trigger_function,
            project || :instance)

          ::SecApplicationRecord.connection.execute("SELECT set_config(
          'vulnerability_management.dont_execute_db_trigger', '#{feature_enabled}', true);")

          self.class::SEC_DB_TASKS.each { |task| execute_task(task) }
        end
      end

      def run_tasks_in_main_db
        ::ApplicationRecord.transaction do
          self.class::MAIN_DB_TASKS.each { |task| execute_task(task) }
        end
      end

      def execute_task(task)
        Tasks.const_get(task, false).execute(pipeline, finding_maps, context)
      end

      def context
        Context.new
      end
      strong_memoize_attr :context

      # TODO: With FF removal tracked in https://gitlab.com/gitlab-org/gitlab/-/issues/536299
      # 1. Remove preloading logic
      def update_elasticsearch
        return unless ::Search::Elastic::VulnerabilityIndexingHelper.vulnerability_indexing_allowed?

        # rubocop:disable CodeReuse/ActiveRecord -- short lived code will be removed with FF.
        vulnerabilities = Vulnerability.includes(:project, :group).where(id: vulnerability_ids)
        # rubocop:enable CodeReuse/ActiveRecord

        eligible_vulnerabilities = vulnerabilities.select(&:maintaining_elasticsearch?)

        eligible_vulnerabilities.each do |vulnerability|
          ::Elastic::ProcessBookkeepingService.track!(vulnerability)
        end
      end

      def vulnerability_ids
        @vulnerability_ids ||= finding_maps.map(&:vulnerability_id)
      end
    end
  end
end
