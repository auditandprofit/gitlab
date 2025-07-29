# frozen_string_literal: true

class ElasticClusterReindexingCronWorker
  include ApplicationWorker
  include Search::Worker

  data_consistency :always
  include CronjobQueue # rubocop:disable Scalability/CronWorkerContext
  include Gitlab::ExclusiveLeaseHelpers
  prepend ::Geo::SkipSecondary

  sidekiq_options retry: false

  urgency :throttled
  idempotent!

  def perform
    return false unless ::Gitlab::CurrentSettings.elasticsearch_indexing?

    in_lock(self.class.name.underscore, ttl: 1.hour, retries: 10, sleep_sec: 1) do
      Search::Elastic::ReindexingTask.drop_old_indices!

      task = Search::Elastic::ReindexingTask.current
      break false unless task

      service.execute
    end
  end

  private

  def service
    ::Search::Elastic::ClusterReindexingService.new
  end
end
