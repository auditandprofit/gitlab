# frozen_string_literal: true

module Sbom
  class ComponentVersion < ::SecApplicationRecord
    include SafelyChangeColumnDefault

    columns_changing_default :organization_id

    belongs_to :component, optional: false
    has_many :occurrences, inverse_of: :component_version
    belongs_to :organization, class_name: 'Organizations::Organization'

    validates :version, presence: true, length: { maximum: 255 }

    scope :by_component_id_and_version, ->(component_id, version) do
      where(component_id: component_id, version: version)
    end

    def self.by_project_and_component(project_id, component_name)
      joins(:occurrences)
        .where(sbom_occurrences: { project_id: project_id, component_name: component_name })
        .select_distinct(on: "version")
        .order(version: :asc)
    end

    def self.by_group_and_component(group, component_name)
      component_names_group_query(
        group.traversal_ids,
        group.next_traversal_ids,
        component_name
      )
    end

    def self.component_names_group_query(start_id, end_id, component_name)
      sql = <<~SQL
        WITH RECURSIVE component_versions AS (
          SELECT
            *
          FROM (
              SELECT
                traversal_ids,
                component_name,
                component_version_id
              FROM
                sbom_occurrences
              WHERE
                traversal_ids >= '{:start_id}'
                AND traversal_ids < '{:end_id}'
                AND component_name = :component_name COLLATE "C"
              ORDER BY
                sbom_occurrences.traversal_ids ASC,
                sbom_occurrences.component_name COLLATE "C" ASC,
                sbom_occurrences.component_version_id ASC
              LIMIT 1
            ) sub_select
          UNION ALL
          SELECT
            lateral_query.traversal_ids,
            lateral_query.component_name,
            lateral_query.component_version_id
          FROM
            component_versions,
            LATERAL (
              SELECT
                sbom_occurrences.traversal_ids,
                sbom_occurrences.component_name,
                sbom_occurrences.component_version_id
              FROM
                sbom_occurrences
              WHERE
                sbom_occurrences.traversal_ids >= '{:start_id}'
                AND sbom_occurrences.traversal_ids < '{:end_id}'
                AND (sbom_occurrences.traversal_ids,
                    sbom_occurrences.component_name,
                    sbom_occurrences.component_version_id) > (component_versions.traversal_ids,
                    component_versions.component_name,
                    component_versions.component_version_id)
                AND component_name = :component_name COLLATE "C"
              ORDER BY
                sbom_occurrences.traversal_ids ASC,
                sbom_occurrences.component_name COLLATE "C" ASC,
                sbom_occurrences.component_version_id ASC
              LIMIT 1
            ) lateral_query
        )
        SELECT
          component_versions.component_version_id AS id
        FROM
          component_versions
      SQL

      query_params = {
        start_id: start_id,
        end_id: end_id,
        component_name: component_name
      }

      sql = sanitize_sql_array([sql, query_params])
      where("id IN (#{sql})") # rubocop:disable GitlabSecurity/SqlInjection -- sanitized above
        .select_distinct(on: "version")
        .order(version: :asc)
    end

    def self.select_distinct(on:)
      select_values = column_names.map do |column|
        connection.quote_table_name("#{table_name}.#{column}")
      end

      distinct_values = Array(on).map { |column| arel_table[column] }
      distinct_sql = Arel::Nodes::DistinctOn.new(distinct_values).to_sql

      select("#{distinct_sql} #{select_values.join(', ')}")
    end
  end
end
