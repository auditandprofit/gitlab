# frozen_string_literal: true

class ElasticRemoveExpiredNamespaceSubscriptionsFromIndexCronWorker
  include ApplicationWorker
  include Search::Worker
  prepend ::Geo::SkipSecondary

  data_consistency :always
  pause_control :advanced_search

  include Gitlab::ExclusiveLeaseHelpers
  include CronjobQueue # rubocop:disable Scalability/CronWorkerContext -- This is a cron job

  idempotent!

  def perform
    return false unless ::Gitlab::Saas.feature_available?(:advanced_search)

    namespaces_removed = ::Search::Elastic::DestroyExpiredSubscriptionService.new.execute

    log_extra_metadata_on_done(:namespaces_removed_count, namespaces_removed)
  end
end
