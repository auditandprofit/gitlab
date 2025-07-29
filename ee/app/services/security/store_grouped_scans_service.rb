# frozen_string_literal: true

module Security
  class StoreGroupedScansService < ::BaseService
    include ::Gitlab::ExclusiveLeaseHelpers

    LEASE_TTL = 30.minutes
    LEASE_TRY_AFTER = 3.seconds
    LEASE_NAMESPACE = "store_grouped_scans"

    def self.execute(artifacts, pipeline, file_type)
      new(artifacts, pipeline, file_type).execute
    end

    def initialize(artifacts, pipeline, file_type)
      @artifacts = artifacts
      @pipeline = pipeline
      @known_keys = Set.new
      @file_type = file_type&.to_s
    end

    def execute
      scan_result = in_lock(lease_key, ttl: LEASE_TTL, sleep_sec: LEASE_TRY_AFTER) do
        sorted_artifacts.reduce(false) do |deduplicate, artifact|
          store_scan_for(artifact, deduplicate)
        end
      end

      record_error_rate
      scan_result
    rescue Gitlab::Ci::Parsers::ParserError => error
      Gitlab::ErrorTracking.track_exception(error)
    ensure
      ::Ci::CompareSecurityReportsService.set_security_report_type_to_ready(
        pipeline_id: pipeline.id,
        report_type: file_type
      )
      artifacts.each(&:clear_security_report)
    end

    private

    attr_reader :artifacts, :pipeline, :known_keys, :file_type

    def lease_key
      "#{LEASE_NAMESPACE}:#{pipeline.id}:#{file_type}"
    end

    def sorted_artifacts
      @sorted_artifacts ||= artifacts.each { |artifact| prepare_report_for(artifact) }.sort do |a, b|
        report_a = a.security_report
        report_b = b.security_report

        report_a.scanner_order_to(report_b)
      end
    end

    def prepare_report_for(artifact)
      artifact.security_report(validate: true)
    end

    def store_scan_for(artifact, deduplicate)
      StoreScanService.execute(artifact, known_keys, deduplicate)
    end

    def record_error_rate
      return if Feature.disabled?(:security_scan_error_rate, Feature.current_request, type: :wip)

      sorted_artifacts.each do |artifact|
        scan = artifact.security_report&.scan

        next unless scan

        feature_category = Enums::Vulnerability.report_type_feature_category(scan.type)

        Gitlab::Metrics::SecurityScanSlis.error_rate.increment(
          labels: { scan_type: scan.type, feature_category: feature_category },
          # https://gitlab.com/gitlab-org/security-products/security-report-schemas/-/blob/941f497a3824d4393eb8a7efced497f738895ab4/src/security-report-format.json#L128
          error: scan.status != "success"
        )
      end
    end
  end
end
