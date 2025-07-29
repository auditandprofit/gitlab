# frozen_string_literal: true

module Security
  # This service class stores the findings metadata for all pipelines.
  class StoreFindingsService < ::BaseService
    BATCH_SIZE = 50

    attr_reader :security_scan, :report, :deduplicated_finding_uuids

    def self.execute(security_scan, scanner, report, deduplicated_finding_uuids)
      new(security_scan, scanner, report, deduplicated_finding_uuids).execute
    end

    def initialize(security_scan, scanner, report, deduplicated_finding_uuids)
      @security_scan = security_scan
      @scanner = scanner
      @report = report
      @deduplicated_finding_uuids = deduplicated_finding_uuids
    end

    def execute
      return error('Findings are already stored!') if already_stored?

      store_findings
      success
    end

    private

    attr_reader :scanner

    delegate :project, to: :security_scan

    def already_stored?
      security_scan.findings.any?
    end

    def store_findings
      report_findings.each_slice(BATCH_SIZE) { |batch| store_finding_batch(batch) }
    end

    def report_findings
      report.findings.select(&:valid?)
    end

    def store_finding_batch(batch)
      batch.map { finding_data(_1) }
           .then { import_batch(_1) }
    end

    def import_batch(report_finding_data)
      Security::Finding.insert_all(report_finding_data, unique_by: findings_unique_by)
    end

    # This will force the ActiveRecord to use the `security_findings_pk`
    # and don't do UPSERT.
    def findings_unique_by
      Security::Finding.connection.schema_cache.primary_keys(Security::Finding.table_name)
    end

    def finding_data(report_finding)
      {
        scan_id: security_scan.id,
        project_id: project.id,
        partition_number: security_scan.findings_partition_number,
        severity: report_finding.severity,
        uuid: report_finding.uuid,
        overridden_uuid: report_finding.overridden_uuid,
        scanner_id: scanner.id,
        deduplicated: deduplicated?(report_finding),
        finding_data: finding_data_for(report_finding)
      }
    end

    def deduplicated?(report_finding)
      deduplicated_finding_uuids.include?(report_finding.uuid)
    end

    def finding_data_for(report_finding)
      {
        name: report_finding.name,
        description: report_finding.description,
        solution: report_finding.solution,
        location: report_finding.location_data,
        identifiers: report_finding.identifiers.map(&:to_hash),
        links: report_finding.links.map(&:to_hash),
        false_positive?: report_finding.false_positive?,
        assets: report_finding.assets,
        evidence: report_finding.evidence&.data,
        details: report_finding.details,
        remediation_byte_offsets: report_finding.remediation_byte_offsets,
        raw_source_code_extract: report_finding.raw_source_code_extract
      }
    end
  end
end
