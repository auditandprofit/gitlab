# frozen_string_literal: true

# Deprecation: This class is going to be removed as
# `ee/app/services/click_house/sync_strategies/user_addon_assignment_versions_sync_strategy.rb`
# will take precedence.
# This change is added in %18.1, this class shall be removed in the next 1-3 milestones
# See the following issues for more context:
# - https://gitlab.com/gitlab-org/gitlab/-/issues/545321
# - https://gitlab.com/gitlab-org/gitlab/-/issues/540267
module ClickHouse # rubocop:disable Gitlab/BoundedContexts -- Context already present in other files
  module SyncStrategies
    class UserAddOnAssignmentSyncStrategy < BaseSyncStrategy
      private

      def csv_mapping
        {
          assignment_id: :item_id,
          add_on_name: :add_on_name,
          namespace_path: :namespace_path,
          user_id: :user_id,
          purchase_id: :purchase_id,
          assigned_at: :assigned_at,
          revoked_at: :revoked_at
        }
      end

      def projections
        [
          :id,
          :item_id,
          :add_on_name,
          :namespace_path,
          :user_id,
          :purchase_id,
          calculated_assigned_at,
          "CASE WHEN event = 'destroy' THEN EXTRACT(epoch FROM created_at) END AS revoked_at"
        ]
      end

      # Calculates assigned_at
      #
      # For destroy event it gets the latest assigned_at for the corresponding
      # item_id and its own created_at as revoked_at allowing to skip a materialized view on CH
      # to aggregate these values.
      def calculated_assigned_at
        <<~SQL
           CASE
           WHEN event = 'create' THEN EXTRACT(epoch FROM created_at)
           WHEN event = 'destroy' THEN (
             SELECT EXTRACT(epoch FROM MAX(previous.created_at))
             FROM   "subscription_user_add_on_assignment_versions" AS previous
             WHERE  previous.item_id = subscription_user_add_on_assignment_versions.item_id
                    AND previous.event = 'create'
           )
         END AS assigned_at
        SQL
      end

      def insert_query
        <<~SQL.squish
          INSERT INTO user_add_on_assignments_history (#{csv_mapping.keys.join(', ')})
          SETTINGS async_insert=1, wait_for_async_insert=1 FORMAT CSV
        SQL
      end

      def model_class
        ::GitlabSubscriptions::UserAddOnAssignmentVersion
      end

      def enabled?
        super && Gitlab::ClickHouse.globally_enabled_for_analytics?
      end
    end
  end
end
