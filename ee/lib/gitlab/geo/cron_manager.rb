# frozen_string_literal: true

module Gitlab
  module Geo
    class CronManager
      # This class helps to react to state changes in node types. We currently have non-geo nodes, primary and
      # secondary geo nodes. This manager gets for example executed during Rails initialization, a promotion from a
      # secondary to a primary node, during and also every minute by the `Geo::SidekiqCronConfigWorker` to ensure
      # the correct status of the geo jobs.

      include ::Gitlab::Utils::StrongMemoize

      COMMON_GEO_JOBS = %w[
        geo_metrics_update_worker
        geo_verification_cron_worker
      ].freeze

      # These jobs run on everything, whether Geo is enabled or not
      COMMON_GEO_AND_NON_GEO_JOBS = %w[
        repository_check_worker
      ].freeze

      PRIMARY_GEO_JOBS = %w[
        geo_prune_event_log_worker
      ].freeze

      SECONDARY_GEO_JOBS = %w[
        geo_registry_sync_worker
        geo_repository_registry_sync_worker
        geo_secondary_registry_consistency_worker
        geo_secondary_usage_data_cron_worker
        geo_sync_timeout_cron_worker
      ].freeze

      CONFIG_WATCHER = 'geo_sidekiq_cron_config_worker'
      CONFIG_WATCHER_CLASS = 'Geo::SidekiqCronConfigWorker'

      GEO_JOBS = (COMMON_GEO_JOBS + PRIMARY_GEO_JOBS + SECONDARY_GEO_JOBS).freeze
      GEO_ALWAYS_ENABLED_JOBS = (COMMON_GEO_JOBS + COMMON_GEO_AND_NON_GEO_JOBS).freeze

      def execute
        return unless Geo.connected?

        if current_node&.primary?
          configure_primary
        elsif current_node&.secondary?
          configure_secondary
        else
          configure_non_geo_site
        end
      end

      def create_watcher!
        job(CONFIG_WATCHER)&.destroy

        # TODO: make shard-aware. See https://gitlab.com/gitlab-com/gl-infra/scalability/-/issues/3430
        SidekiqSharding::Validator.allow_unrouted_sidekiq_calls do
          Sidekiq::Cron::Job.create(
            name: CONFIG_WATCHER,
            cron: '*/1 * * * *',
            class: CONFIG_WATCHER_CLASS
          )
        end
      end

      # This method ensures disabled secondary geo jobs are enabled when promoting to a primary node.
      # Applying the default config without `status` attributes won't enable previously disabled jobs.
      def enable_all_jobs!
        enable_jobs!(all_jobs)
      end

      private

      # We avoid the memoized `Gitlab::Geo.current_node`, in particular because it can be
      # stale during `rake set_secondary_as_primary`.
      def current_node
        GeoNode.current_node
      end
      strong_memoize_attr :current_node

      def configure_primary
        disable!(SECONDARY_GEO_JOBS)

        enable!(GEO_ALWAYS_ENABLED_JOBS + PRIMARY_GEO_JOBS)
      end

      def configure_secondary
        names = GEO_ALWAYS_ENABLED_JOBS + SECONDARY_GEO_JOBS

        disable_all_except!(names)
        enable!(names)
      end

      def configure_non_geo_site
        disable!(GEO_JOBS)

        enable!(COMMON_GEO_AND_NON_GEO_JOBS)
      end

      def enable!(names)
        enable_jobs!(jobs(names))
      end

      def disable!(names)
        disable_jobs!(jobs(names))
      end

      def enable_all_except!(names)
        enable_jobs!(all_jobs_except(names))
      end

      def disable_all_except!(names)
        disable_jobs!(all_jobs_except(names))
      end

      def enable_jobs!(jobs)
        jobs.each { |job| job.enable! unless job.enabled? }
      end

      def disable_jobs!(jobs)
        jobs.each { |job| job.disable! unless job.disabled? }
      end

      def all_jobs_except(names = [])
        all_jobs.reject { |job| names.include?(job.name) }
      end

      def all_jobs
        SidekiqSharding::Validator.allow_unrouted_sidekiq_calls { Sidekiq::Cron::Job.all }
      end

      def jobs(names)
        names.filter_map { |name| job(name) }
      end

      def job(name)
        SidekiqSharding::Validator.allow_unrouted_sidekiq_calls do
          Sidekiq::Cron::Job.find(name)
        end
      end
    end
  end
end
