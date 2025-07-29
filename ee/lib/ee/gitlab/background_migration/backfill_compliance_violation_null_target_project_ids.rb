# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module BackfillComplianceViolationNullTargetProjectIds
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          operation_name :backfill_compliance_violations_target_project_ids
          scope_to ->(relation) { relation.where(target_project_id: nil) }
          feature_category :compliance_management
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            connection.execute(<<~SQL)
            UPDATE #{sub_batch.table_name} cv
            SET target_project_id = mr.target_project_id
            FROM merge_requests mr
            WHERE cv.id IN (#{sub_batch.select(:id).to_sql})
              AND cv.merge_request_id = mr.id
              AND cv.target_project_id IS NULL
            SQL
          end
        end

        private

        def connection
          ApplicationRecord.connection
        end
      end
    end
  end
end
