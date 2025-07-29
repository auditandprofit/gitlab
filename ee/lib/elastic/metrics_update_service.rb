# frozen_string_literal: true

module Elastic
  class MetricsUpdateService
    def execute
      incremental_gauge = Gitlab::Metrics.gauge(:search_advanced_bulk_cron_queue_size, 'Number of incremental database updates waiting to be synchronized to Elasticsearch', {}, :max)
      incremental_gauge.set({}, ::Elastic::ProcessBookkeepingService.queue_size)

      initial_gauge = Gitlab::Metrics.gauge(:search_advanced_bulk_cron_initial_queue_size, 'Number of initial database updates waiting to be synchronized to Elasticsearch', {}, :max)
      initial_gauge.set({}, ::Elastic::ProcessInitialBookkeepingService.queue_size)

      embedding_gauge = Gitlab::Metrics.gauge(:search_advanced_bulk_cron_embedding_queue_size, 'Number of embedding updates waiting to be synchronized to Elasticsearch', {}, :max)
      embedding_gauge.set({}, ::Search::Elastic::ProcessEmbeddingBookkeepingService.queue_size)

      # deprecated metrics

      incremental_gauge_deprecated = Gitlab::Metrics.gauge(:global_search_bulk_cron_queue_size, 'Deprecated and planned for removal in 18.0. Number of incremental database updates waiting to be synchronized to Elasticsearch', {}, :max)
      incremental_gauge_deprecated.set({}, ::Elastic::ProcessBookkeepingService.queue_size)

      initial_gauge_deprecated = Gitlab::Metrics.gauge(:global_search_bulk_cron_initial_queue_size, 'Deprecated and planned for removal in 18.0. Number of initial database updates waiting to be synchronized to Elasticsearch', {}, :max)
      initial_gauge_deprecated.set({}, ::Elastic::ProcessInitialBookkeepingService.queue_size)
    end
  end
end
