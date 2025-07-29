# frozen_string_literal: true

module Security
  module AnalyzersStatus
    class SettingChangedUpdateWorker
      include ApplicationWorker

      idempotent!
      data_consistency :sticky
      feature_category :security_asset_inventories
      defer_on_database_health_signal :gitlab_sec, [:analyzer_namespace_statuses], 30.seconds

      def perform(project_ids, analyzer_type)
        return unless project_ids.present? && analyzer_type.present?

        SettingsBasedUpdateService.execute(project_ids, analyzer_type)
      end
    end
  end
end
