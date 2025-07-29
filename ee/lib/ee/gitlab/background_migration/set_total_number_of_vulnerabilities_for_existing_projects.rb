# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module SetTotalNumberOfVulnerabilitiesForExistingProjects
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          operation_name :set_vulnerability_count
        end

        PROJECT_STATISTICS_UPDATE_QUERY = <<~SQL
          UPDATE
            project_security_statistics
          SET
            vulnerability_count = vulnerability_count + $1
          WHERE
            project_id = $2
        SQL

        class ProjectSecurityStatistics < ::SecApplicationRecord; end

        class VulnerabilityRead < ::SecApplicationRecord
          include EachBatch

          self.primary_key = :vulnerability_id
        end

        override :perform
        def perform
          distinct_each_batch do |sub_batch|
            project_ids = sub_batch.pluck(:project_id)

            ensure_statistics(project_ids)

            project_ids.each { |project_id| update_project_statistics(project_id) }
          end
        end

        private

        def ensure_statistics(project_ids)
          project_ids.map { |project_id| { project_id: project_id } }
                     .then { |attributes| ProjectSecurityStatistics.upsert_all(attributes) }
        end

        def update_project_statistics(project_id)
          latest_vulnerability_id = reset_statistics_and_get_latest_vulnerability_id(project_id)
          total_count = calculate_number_of_vulnerabilities(project_id, latest_vulnerability_id)

          persist_statistics(project_id, total_count)
        end

        def reset_statistics_and_get_latest_vulnerability_id(project_id)
          latest_vulnerability_id = nil

          ProjectSecurityStatistics.transaction do
            statistics = ProjectSecurityStatistics.lock.find(project_id)

            latest_vulnerability_id = VulnerabilityRead.where(project_id: project_id).last.vulnerability_id

            statistics.vulnerability_count = 0
            statistics.save!
          end

          latest_vulnerability_id
        end

        def calculate_number_of_vulnerabilities(project_id, latest_vulnerability_id)
          total_count = 0

          VulnerabilityRead.where('project_id = ? AND vulnerability_id <= ?',
            project_id, latest_vulnerability_id).each_batch do |batch|
            total_count += batch.count
          end

          total_count
        end

        def persist_statistics(project_id, total_count)
          bind_params = [total_count, project_id]

          ProjectSecurityStatistics.connection.exec_query(PROJECT_STATISTICS_UPDATE_QUERY, 'UPDATE', bind_params)
        end
      end
    end
  end
end
