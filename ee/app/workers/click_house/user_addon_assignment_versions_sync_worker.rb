# frozen_string_literal: true

module ClickHouse # rubocop:disable Gitlab/BoundedContexts -- Context already present in other files
  class UserAddonAssignmentVersionsSyncWorker
    include ApplicationWorker
    include ClickHouseWorker

    idempotent!
    queue_namespace :cronjob
    data_consistency :delayed
    feature_category :seat_cost_management

    def perform
      return unless enabled?

      result = ::ClickHouse::SyncStrategies::UserAddonAssignmentVersionsSyncStrategy.new.execute
      log_extra_metadata_on_done(:result, result)
    end

    private

    def enabled?
      Gitlab::ClickHouse.globally_enabled_for_analytics?
    end
  end
end
