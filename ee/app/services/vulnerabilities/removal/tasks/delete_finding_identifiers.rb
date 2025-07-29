# frozen_string_literal: true

module Vulnerabilities
  module Removal
    module Tasks
      class DeleteFindingIdentifiers < AbstractTaskScopedToFinding
        DELETE_FINDING_IDENTIFIERS_SQL = <<~SQL
          DELETE FROM vulnerability_occurrence_identifiers
          WHERE id IN (%{ids})
          RETURNING identifier_id
        SQL

        DELETE_IDENTIFIERS_SQL = <<~SQL
          DELETE FROM vulnerability_identifiers
          WHERE
            id IN (%{ids_list})
            AND NOT EXISTS (
                SELECT
                  1
                FROM
                  vulnerability_occurrence_identifiers
                WHERE
                  vulnerability_occurrence_identifiers.identifier_id = vulnerability_identifiers.id
              )
        SQL

        def execute
          loop do
            batch = Vulnerabilities::FindingIdentifier.by_finding_id(finding_ids).limit(100)

            deleted_identifier_ids = delete_finding_identifiers(batch)

            break if deleted_identifier_ids.blank?

            delete_related_identifiers(deleted_identifier_ids)
          end
        end

        private

        delegate :connection, to: Vulnerabilities::FindingIdentifier, private: true

        def delete_finding_identifiers(batch)
          batch.select(:id).to_sql
            .then { |subquery| format(DELETE_FINDING_IDENTIFIERS_SQL, ids: subquery) }
            .then { |delete_sql| connection.exec_query(delete_sql, 'DELETE FINDING IDENTIFIERS') }
            .rows
            .flatten
        end

        def delete_related_identifiers(deleted_identifier_ids)
          deleted_identifier_ids.join(', ')
            .then { |ids_list| format(DELETE_IDENTIFIERS_SQL, ids_list: ids_list) }
            .then { |delete_sql| connection.exec_query(delete_sql, 'DELETE IDENTIFIERS') }
        end
      end
    end
  end
end
