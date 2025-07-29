# frozen_string_literal: true

# Deprecation: This class is going to be removed as
# `ee/app/workers/click_house/user_addon_assignment_versions_sync_worker.rb`
# will take precedence.
# This change is added in %18.1, this class shall be removed in the next 1-3 milestones
# See the following issues for more context:
# - https://gitlab.com/gitlab-org/gitlab/-/issues/545321
# - https://gitlab.com/gitlab-org/gitlab/-/issues/540267
module ClickHouse # rubocop:disable Gitlab/BoundedContexts -- Context already present in other files
  class UserAddOnAssignmentsSyncWorker
    include ApplicationWorker
    include ClickHouseWorker

    idempotent!
    queue_namespace :cronjob
    data_consistency :delayed
    feature_category :seat_cost_management

    def perform
      return unless enabled?

      result = ::ClickHouse::SyncStrategies::UserAddOnAssignmentSyncStrategy.new.execute
      log_extra_metadata_on_done(:result, result)
    end

    private

    def enabled?
      Gitlab::ClickHouse.globally_enabled_for_analytics?
    end
  end
end
