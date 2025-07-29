# frozen_string_literal: true

module ClickHouse # rubocop:disable Gitlab/BoundedContexts -- Context already present in other files
  module SyncStrategies
    class UserAddonAssignmentVersionsSyncStrategy < BaseSyncStrategy
      private

      def csv_mapping
        {
          id: :id,
          organization_id: :organization_id,
          item_id: :item_id,
          user_id: :user_id,
          purchase_id: :purchase_id,
          namespace_path: :namespace_path,
          add_on_name: :add_on_name,
          event: :event,
          created_at: :casted_created_at
        }
      end

      def projections
        [
          :id,
          :organization_id,
          :item_id,
          :user_id,
          :purchase_id,
          :namespace_path,
          :add_on_name,
          :event,
          'EXTRACT(epoch FROM created_at) AS casted_created_at'
        ]
      end

      def insert_query
        <<~SQL.squish
          INSERT INTO subscription_user_add_on_assignment_versions (#{csv_mapping.keys.join(', ')})
          SETTINGS async_insert=1, wait_for_async_insert=1 FORMAT CSV
        SQL
      end

      def model_class
        ::GitlabSubscriptions::UserAddOnAssignmentVersion
      end

      def sync_cursor_identifier
        "user_addon_assignment_versions"
      end

      def enabled?
        super && Gitlab::ClickHouse.globally_enabled_for_analytics?
      end
    end
  end
end
