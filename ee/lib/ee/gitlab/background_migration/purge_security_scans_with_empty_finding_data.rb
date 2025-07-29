# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module PurgeSecurityScansWithEmptyFindingData
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        SUCCEDED_STATUS = 1
        PURGED_STATUS = 6
        FINISHED_MIGRATION_STATUS = 3

        prepended do
          operation_name :purge_security_scans
          scope_to ->(relation) { relation.where(status: SUCCEDED_STATUS) }
        end

        class SecurityFinding < SecApplicationRecord
          self.table_name = 'security_findings'

          # Returns only the first findings for each scan
          scope :first_findings_by_scan_ids, ->(scan_ids) do
            from("unnest('{#{scan_ids.join(', ')}}'::bigint[]) AS scan_ids(id), ")
              .joins(<<~SQL)
                LATERAL (
                  SELECT
                    sub_findings.*
                  FROM
                    security_findings sub_findings
                  WHERE
                    sub_findings.scan_id = scan_ids.id
                  ORDER BY
                    sub_findings.id ASC
                  LIMIT 1
                ) AS security_findings
              SQL
          end
        end

        class SecurityScan < SecApplicationRecord
          self.table_name = 'security_scans'

          scope :by_ids, ->(ids) { where(id: ids) }
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            scan_ids = sub_batch.pluck(:id)

            first_findings = SecurityFinding.first_findings_by_scan_ids(scan_ids)

            first_findings.select { |finding| finding.finding_data.empty? }
                          .map(&:scan_id)
                          .then { |scan_ids| SecurityScan.by_ids(scan_ids) }
                          .then { |relation| relation.update_all(status: PURGED_STATUS) }

            mark_migration_as_complete if first_findings.any? { |finding| finding.finding_data.present? }
          end
        end

        private

        def mark_migration_as_complete
          ::Gitlab::Database::SharedModel.using_connection(ApplicationRecord.connection) do
            migration.update_columns(status: FINISHED_MIGRATION_STATUS, finished_at: Time.current)
          end
        end

        def migration
          ::Gitlab::Database::BackgroundMigration::BatchedMigration.find_for_configuration(
            :gitlab_main,
            'PurgeSecurityScansWithEmptyFindingData',
            :security_scans,
            :id,
            []
          )
        end
      end
    end
  end
end
