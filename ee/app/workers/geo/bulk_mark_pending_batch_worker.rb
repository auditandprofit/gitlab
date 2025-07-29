# frozen_string_literal: true

module Geo
  # Worker that marks registries as pending in batches
  # to be resynchronized by Geo periodic workers
  class BulkMarkPendingBatchWorker
    include ApplicationWorker

    data_consistency :always

    include GeoQueue
    include LimitedCapacity::Worker
    include ::Gitlab::Geo::LogHelpers

    # Maximum number of jobs allowed to run concurrently
    MAX_RUNNING_JOBS = 1
    # Reset the Redis cursor to start processing registries
    INITIAL_REDIS_CURSOR = 0

    idempotent!
    loggable_arguments 0

    class << self
      def perform_with_capacity(...)
        restart_redis_cursor(...)

        super(...)
      end

      private

      def restart_redis_cursor(...)
        ::Geo::BulkMarkPendingService.new(...).set_bulk_mark_update_cursor(INITIAL_REDIS_CURSOR)
      end
    end

    def perform_work(...)
      ::Geo::BulkMarkPendingService.new(...).mark_one_batch_to_update_with_lease!
    end

    # Number of remaining jobs that this worker needs to perform
    #
    # @param registry_class [String] Registry class of the data type being bulk resynced
    # @param params [Hash] optional options to filter the records being resynced
    # @return [Integer] The number of remaining batches of registry rows that need to be marked pending
    def remaining_work_count(...)
      @remaining_work_count ||= ::Geo::BulkMarkPendingService.new(...)
        .remaining_batches_to_bulk_mark_update(
          max_batch_count: max_running_jobs
        )
    end

    def max_running_jobs
      MAX_RUNNING_JOBS
    end
  end
end
