# frozen_string_literal: true

module Ai
  module ActiveContext
    class MigrationWorker
      include ::ActiveContext::Concerns::MigrationWorker
      include ::ApplicationWorker
      include ::CronjobQueue
      include Gitlab::ExclusiveLeaseHelpers
      prepend ::Geo::SkipSecondary

      idempotent!
      worker_resource_boundary :cpu
      urgency :low
      data_consistency :sticky
      feature_category :global_search
    end
  end
end
