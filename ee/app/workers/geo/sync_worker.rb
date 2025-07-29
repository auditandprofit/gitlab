# frozen_string_literal: true

module Geo
  # Enqueued by RegistrySyncWorker and RepositoryRegistrySyncWorker
  # to perform syncs. These syncs are distinct from Geo update events
  # because these syncs do not begin by marking the registry pending.
  class SyncWorker
    include ApplicationWorker
    include GeoQueue

    idempotent!
    worker_has_external_dependencies!
    data_consistency :sticky
    sidekiq_options retry: false, dead: false
    loggable_arguments 0, 1

    def perform(replicable_name, model_record_id)
      Geo::SyncService.new(replicable_name, model_record_id).execute
    end
  end
end
