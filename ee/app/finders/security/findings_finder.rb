# frozen_string_literal: true

# Security::FindingsFinder
#
# This finder returns an `ActiveRecord::Relation` of the
# `Security::Finding`s associated with a pipeline.
#
# Arguments:
#   pipeline - object to filter findings
#   params:
#     severity:    Array<String>
#     report_type: Array<String>
#     scope:       String
#     limit:       Int

module Security
  class FindingsFinder
    DEFAULT_LIMIT = 20

    def initialize(pipeline, params: {})
      @pipeline = pipeline
      @params = params
    end

    def execute
      # This method generates a query of the general form
      #
      #   SELECT security_findings.*
      #   FROM security_scans
      #   LATERAL (
      #     SELECT * FROM security_findings
      #     LIMIT n
      #   )
      #   WHERE security_scans.x = 'y'
      #   ...
      #
      # This is done for performance reasons to reduce the amount of data loaded
      # in the query compared to a more conventional
      #
      #   SELECT security_findings.*
      #   FROM security_findings
      #   JOIN security_scans ...
      #
      # The latter form can end up reading a very large number of rows on projects
      # with high numbers of findings.
      #
      # Note the inner query needs the LIMIT incremented by 1 because of the
      # way the Kaminari gem implements pagination without total counts.
      # Kaminari increments the LIMIT on the outer relation query by 1 to
      # determine if there are further pages to load. See https://github.com/kaminari/kaminari/blob/13b59ce7ab4e3d0e3072272251de734f918d5f8f/kaminari-activerecord/lib/kaminari/activerecord/active_record_relation_methods.rb#L83-L101

      return Security::Finding.none unless pipeline

      lateral_relation = Security::Finding
        .left_joins_vulnerability_finding
        .where('"security_findings"."scan_id" = "security_scans"."id"') # rubocop:disable CodeReuse/ActiveRecord
        .where( # rubocop:disable CodeReuse/ActiveRecord
          # prefer "vulnerability_occurrences" severities for security findings whose severity has been overridden
          'COALESCE("vulnerability_occurrences"."severity", "security_findings"."severity") = "severities"."severity"'
        )
        .by_partition_number(security_findings_partition_number)
        .deduplicated
        .ordered(params[:sort])
        .then { |relation| by_uuid(relation) }
        .then { |relation| by_scanner_external_ids(relation) }
        .then { |relation| by_state(relation) }
        .then { |relation| by_include_dismissed(relation) }
        .limit(limit + 1)

      from_sql = <<~SQL.squish
          "security_scans",
          unnest('{#{severities.join(',')}}'::smallint[]) AS "severities" ("severity"),
          LATERAL (#{lateral_relation.to_sql}) AS "security_findings"
      SQL

      Security::Finding
        .from(from_sql) # rubocop:disable CodeReuse/ActiveRecord
        .with_pipeline_entities
        .with_scan
        .with_scanner
        .with_state_transitions
        .with_issue_links
        .with_external_issue_links
        .with_merge_request_links
        .with_feedbacks
        .with_vulnerability
        .merge(::Security::Scan.by_pipeline_ids(pipeline_ids))
        .merge(::Security::Scan.latest_successful)
        .ordered(params[:sort])
        .then { |relation| by_report_types(relation) }
    end

    private

    attr_reader :pipeline, :params

    delegate :project, :security_findings_partition_number, to: :pipeline, private: true

    def limit
      @limit ||= params[:limit] || DEFAULT_LIMIT
    end

    def pipeline_ids
      if Feature.enabled?(:show_child_reports_in_mr_page, project)
        # rubocop:disable Database/AvoidUsingPluckWithoutLimit, CodeReuse/ActiveRecord -- Pluck is more efficient & limit of 1000 by default
        pipeline.self_and_project_descendants.pluck(:id)
        # rubocop:enable Database/AvoidUsingPluckWithoutLimit, CodeReuse/ActiveRecord
      else
        [pipeline.id]
      end
    end

    def include_dismissed?
      params[:scope] == 'all' || params[:state]
    end

    def by_include_dismissed(relation)
      return relation if include_dismissed?

      relation.undismissed_by_vulnerability
    end

    def by_scanner_external_ids(relation)
      return relation unless params[:scanner].present?

      relation.by_scanners(project.vulnerability_scanners.with_external_id(params[:scanner]))
    end

    def by_state(relation)
      return relation unless params[:state].present?

      relation.by_state(params[:state])
    end

    def by_report_types(relation)
      return relation unless params[:report_type]

      relation.merge(::Security::Scan.by_scan_types(params[:report_type]))
    end

    def severities
      if params[:severity]
        Security::Finding.severities.fetch_values(*params[:severity])
      else
        Security::Finding.severities.values
      end
    end

    def by_uuid(relation)
      return relation unless params[:uuid]

      relation.by_uuid(params[:uuid])
    end
  end
end
