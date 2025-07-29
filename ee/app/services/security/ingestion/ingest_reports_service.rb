# frozen_string_literal: true

module Security
  module Ingestion
    # Service for starting the ingestion of the security reports
    # into the database.
    class IngestReportsService
      def self.execute(pipeline)
        new(pipeline).execute
      end

      def initialize(pipeline)
        @pipeline = pipeline
        @original_archived_value = project.archived
        @original_traversal_ids_value = project.namespace.traversal_ids
      end

      def execute
        store_reports
        mark_resolved_vulnerabilities
        mark_project_as_vulnerable!
        set_latest_pipeline!
        schedule_mark_dropped_vulnerabilities
        sync_findings_to_approval_rules
        schedule_sbom_records
        schedule_updating_archived_status_if_needed
        schedule_updating_traversal_ids_if_needed
      end

      private

      attr_reader :pipeline, :original_archived_value, :original_traversal_ids_value

      delegate :project, to: :pipeline, private: true

      def store_reports
        latest_security_scans.flat_map do |scan|
          # Can be removed after https://gitlab.com/gitlab-com/content-sites/handbook/-/merge_requests/10365
          next unless valid_scanner?(scan)

          ingest(scan).then { |ingested_ids| collect_ingested_ids_for(scan, ingested_ids) }
        end
      end

      def collect_ingested_ids_for(scan, ingested_ids)
        ingested_ids_by_scanner[scan.scanner] += ingested_ids
      end

      def latest_security_scans
        @latest_security_scans ||= pipeline.root_ancestor.self_and_descendant_security_scans.without_errors.latest
      end

      def ingested_ids_by_scanner
        @ingested_ids_by_scanner ||= Hash.new { [] }
      end

      def ingest(security_scan)
        IngestReportService.execute(security_scan)
      end

      def mark_project_as_vulnerable!
        project.mark_as_vulnerable! if ingested_vulnerabilities?
      end

      def ingested_vulnerabilities?
        ingested_ids_by_scanner.values.any?(&:present?)
      end

      def set_latest_pipeline!
        Vulnerabilities::Statistic.set_latest_pipeline_with(pipeline)
      end

      def mark_resolved_vulnerabilities
        ingested_ids_by_scanner.each do |scanner, ingested_ids|
          MarkAsResolvedService.execute(pipeline, scanner, ingested_ids)
        end
      end

      def schedule_mark_dropped_vulnerabilities
        primary_identifiers_by_scan_type.each do |scan_type, identifiers|
          ScheduleMarkDroppedAsResolvedService.execute(pipeline.project_id, scan_type, identifiers)
        end
      end

      def sync_findings_to_approval_rules
        return unless project.licensed_feature_available?(:security_orchestration_policies)

        Security::ScanResultPolicies::SyncFindingsToApprovalRulesWorker.perform_async(pipeline.id)
      end

      def primary_identifiers_by_scan_type
        latest_security_scans.group_by(&:scan_type)
                             .transform_values { |scans| scans.flat_map(&:report_primary_identifiers).compact }
      end

      def schedule_sbom_records
        ::Sbom::ScheduleIngestReportsService.new(pipeline).execute
      end

      def schedule_updating_archived_status_if_needed
        return unless archived_value_changed?

        Vulnerabilities::UpdateArchivedAttributeOfVulnerabilityReadsWorker.perform_async(project.id)
      end

      def schedule_updating_traversal_ids_if_needed
        return unless traversal_ids_value_changed?

        Vulnerabilities::UpdateNamespaceIdsOfVulnerabilityReadsWorker.perform_async(project.id)
      end

      def archived_value_changed?
        reloaded_project.archived != original_archived_value
      end

      def traversal_ids_value_changed?
        reloaded_project.namespace.traversal_ids != original_traversal_ids_value
      end

      def reloaded_project
        @reloaded_project ||= project.reset
      end

      def valid_scanner?(scan)
        scan.scanner.present?
      end
    end
  end
end
