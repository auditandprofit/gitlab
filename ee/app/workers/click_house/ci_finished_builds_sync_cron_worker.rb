# frozen_string_literal: true

module ClickHouse
  class CiFinishedBuildsSyncCronWorker
    include ApplicationWorker

    version 2

    idempotent!
    queue_namespace :cronjob
    data_consistency :delayed
    feature_category :fleet_visibility
    loggable_arguments 1

    def perform(*args)
      return unless job_version == 2
      return unless ::ClickHouse::DataIngestion::CiFinishedBuildsSyncService.enabled?

      total_workers = args.first || 1

      total_workers.times do |worker_index|
        CiFinishedBuildsSyncWorker.perform_async(worker_index, total_workers)
      end

      nil
    end
  end
end
