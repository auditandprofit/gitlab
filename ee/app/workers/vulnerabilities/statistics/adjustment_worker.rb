# frozen_string_literal: true

module Vulnerabilities
  module Statistics
    class AdjustmentWorker # rubocop:disable Scalability/IdempotentWorker
      include ApplicationWorker

      data_consistency :always

      sidekiq_options retry: 3

      feature_category :vulnerability_management

      def perform(project_ids)
        diffs = AdjustmentService.execute(project_ids)
        NamespaceStatistics::UpdateService.execute(diffs)

        inserted_project_ids = HistoricalStatistics::AdjustmentService.execute(project_ids)
        NamespaceHistoricalStatistics::AdjustmentService.execute(inserted_project_ids)
      end
    end
  end
end
