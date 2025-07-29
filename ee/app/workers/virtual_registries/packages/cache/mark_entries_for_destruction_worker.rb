# frozen_string_literal: true

module VirtualRegistries
  module Packages
    module Cache
      class MarkEntriesForDestructionWorker
        include ApplicationWorker

        BATCH_SIZE = 500

        data_consistency :sticky
        queue_namespace :dependency_proxy_blob
        feature_category :virtual_registry
        urgency :low
        defer_on_database_health_signal :gitlab_main, [:virtual_registries_packages_maven_cache_entries], 5.minutes
        deduplicate :until_executed
        idempotent!

        def perform(upstream_id)
          upstream = ::VirtualRegistries::Packages::Maven::Upstream.find_by_id(upstream_id)

          return unless upstream

          upstream.default_cache_entries.each_batch(of: BATCH_SIZE, column: :relative_path) do |batch|
            batch.update_all(
              status: :pending_destruction,
              relative_path: Arel.sql("relative_path || '/deleted/' || gen_random_uuid()"),
              updated_at: Time.current
            )
          end
        end
      end
    end
  end
end
