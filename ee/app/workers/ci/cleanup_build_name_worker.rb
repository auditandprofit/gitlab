# frozen_string_literal: true

module Ci
  class CleanupBuildNameWorker
    include ApplicationWorker
    include CronjobQueue # rubocop:disable Scalability/CronWorkerContext -- does not perform work scoped to a context

    urgency :throttled
    idempotent!
    deduplicate :until_executed
    feature_category :continuous_integration
    data_consistency :sticky
    concurrency_limit -> { 1 }
    defer_on_database_health_signal :gitlab_ci, [:p_ci_build_names], 10.minutes

    MAX_RUNTIME = 2.minutes
    BATCH_SIZE = 10_000
    SUB_BATCH_SIZE = 1_000
    CUT_OFF_DATE = 3
    SLEEP_INTERVAL = 0.1

    # rubocop:disable CodeReuse/ActiveRecord -- specialized delete queries not suitable on model level
    def perform
      return unless Feature.enabled?(:truncate_build_names, :instance)
      return unless build_id_to_delete_before

      runtime_limiter = Gitlab::Metrics::RuntimeLimiter.new(MAX_RUNTIME)

      Ci::BuildName.where(build_id: ..build_id_to_delete_before)
        .each_batch(of: BATCH_SIZE) do |batch|
        batch.each_batch(of: SUB_BATCH_SIZE) do |sub_batch|
          sub_batch.delete_all
          sleep(SLEEP_INTERVAL)
        end

        next unless runtime_limiter.over_time?

        self.class.perform_in(MAX_RUNTIME)

        break
      end
    end

    private

    # We use success here to utilize existing index. As this deletion only needs to be approximate
    # we can be lenient on the criteria
    def build_id_to_delete_before
      @id ||= Ci::Build.success.created_before(CUT_OFF_DATE.months.ago).order(status: :desc, created_at: :desc)
        .limit(1).first&.id
    end
    # rubocop:enable CodeReuse/ActiveRecord
  end
end
