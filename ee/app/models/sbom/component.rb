# frozen_string_literal: true

module Sbom
  class Component < ::SecApplicationRecord
    include SafelyChangeColumnDefault

    columns_changing_default :organization_id

    has_many :occurrences, inverse_of: :component

    enum :component_type, ::Enums::Sbom.component_types
    enum :purl_type, ::Enums::Sbom.purl_types

    belongs_to :organization, class_name: 'Organizations::Organization'

    validates :component_type, presence: true
    validates :name, presence: true, length: { maximum: 255 }

    scope :libraries, -> { where(component_type: :library) }
    scope :by_purl_type_and_name, ->(purl_type, name) do
      where(name: name, purl_type: purl_type)
    end

    scope :by_unique_attributes, ->(name, purl_type, component_type, organization_id) do
      where(name: name, purl_type: purl_type, component_type: component_type, organization_id: organization_id)
    end

    scope :by_name, ->(name) do
      where('name ILIKE ?', "%#{sanitize_sql_like(name)}%") # rubocop:disable GitlabSecurity/SqlInjection -- using sanitize_sql_like here
    end

    DEFAULT_COMPONENT_NAMES_LIMIT = 30
    def self.by_namespace(namespace, query, limit = DEFAULT_COMPONENT_NAMES_LIMIT)
      case namespace
      when Group
        component_names_group_query(
          namespace.traversal_ids,
          namespace.next_traversal_ids,
          query,
          limit
        )
      when Project
        # rubocop:disable GitlabSecurity/SqlInjection -- sanitized
        sanitized_query = sanitize_sql_like(query || '')

        joins(:occurrences)
          .where(sbom_occurrences: { project_id: namespace.id })
          .where('sbom_components.name ILIKE ?', "%#{sanitized_query}%")
          .order(name: :asc)
          .select_distinct(on: "name")
          .limit(limit)
        # rubocop:enable GitlabSecurity/SqlInjection
      else
        Sbom::Component.none
      end
    end

    # In addition we need to perform a loose index scan with custom collation for performance reasons.
    # Sorting can be unpredictable for words containing non-ASCII characters, but dependency names
    # are usually ASCII
    # See https://gitlab.com/gitlab-org/gitlab/-/issues/442407#note_2099802302 for performance
    def self.component_names_group_query(start_id, end_id, query, limit)
      query ||= ""

      sql = <<~SQL
        WITH RECURSIVE component_names AS (
          SELECT
            *
          FROM (
              SELECT
                traversal_ids,
                component_name,
                component_id
              FROM
                sbom_occurrences
              WHERE
                traversal_ids >= '{:start_id}'
                AND traversal_ids < '{:end_id}'
                AND component_name LIKE :query COLLATE "C"
              ORDER BY
                sbom_occurrences.component_name COLLATE "C" ASC
              LIMIT 1
            ) sub_select
          UNION ALL
          SELECT
            lateral_query.traversal_ids,
            lateral_query.component_name,
            lateral_query.component_id
          FROM
            component_names,
            LATERAL (
              SELECT
                sbom_occurrences.traversal_ids,
                sbom_occurrences.component_name,
                sbom_occurrences.component_id
              FROM
                sbom_occurrences
              WHERE
                sbom_occurrences.traversal_ids >= '{:start_id}'
                AND sbom_occurrences.traversal_ids < '{:end_id}'
                AND component_name LIKE :query COLLATE "C"
                AND sbom_occurrences.component_name > component_names.component_name
              ORDER BY
                sbom_occurrences.component_name COLLATE "C" ASC
              LIMIT 1
            ) lateral_query
        )
        SELECT
          component_names.component_id AS id
        FROM
          component_names
      SQL

      sanitized_query = sanitize_sql_like(query)

      query_params = {
        start_id: start_id,
        end_id: end_id,
        query: "#{sanitized_query}%"
      }

      sql = sanitize_sql_array([sql, query_params])
      where("id IN (#{sql})") # rubocop:disable GitlabSecurity/SqlInjection -- sanitized above
        .select_distinct(on: "name")
        .order(name: :asc)
        .limit(limit)
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
