# frozen_string_literal: true

module Security
  class StoreScansService
    include ::Gitlab::Utils::StrongMemoize

    def self.execute(pipeline)
      new(pipeline).execute
    end

    def initialize(pipeline)
      @pipeline = pipeline
    end

    def execute
      return if already_purged?

      # StoreGroupedScansService returns true only when it creates a `security_scans` record.
      # To avoid resource wastage we are skipping the reports ingestion when there are no new scans, but
      # we sync the rules as it might cause inconsistent state if we skip.
      results = security_report_artifacts.map do |file_type, artifacts|
        StoreGroupedScansService.execute(artifacts, pipeline, file_type)
      end

      if sbom_report_artifacts.present?
        results += sbom_report_artifacts.map do |file_type, artifacts|
          StoreGroupedSbomScansService.execute(artifacts, pipeline, file_type)
        end
      end

      sync_findings_to_approval_rules unless pipeline.default_branch?
      return unless results.any?(true)

      schedule_store_reports_worker
      schedule_scan_security_report_secrets_worker
    end

    private

    attr_reader :pipeline

    delegate :project, to: :pipeline, private: true

    def already_purged?
      pipeline.security_scans.purged.any?
    end

    def grouped_report_artifacts
      pipeline.job_artifacts
        .security_reports(file_types: security_report_file_types)
        .group_by(&:file_type)
    end
    strong_memoize_attr :grouped_report_artifacts

    def security_report_artifacts
      grouped_report_artifacts.reject { |file_type| file_type == 'cyclonedx' || !parse_report_file?(file_type) }
    end
    strong_memoize_attr :security_report_artifacts

    def sbom_report_artifacts
      grouped_report_artifacts['cyclonedx']&.each_with_object({}) do |artifact, object|
        next if artifact.security_report.blank? || !parse_report_file?(artifact.security_report.type.to_s)

        (object[artifact.security_report.type.to_s] ||= []) << artifact
      end
    end
    strong_memoize_attr :sbom_report_artifacts

    def security_report_file_types
      EE::Enums::Ci::JobArtifact.security_report_and_cyclonedx_report_file_types
    end

    def parse_report_file?(file_type)
      project.feature_available?(Ci::Build::LICENSED_PARSER_FEATURES.fetch(file_type))
    end

    def schedule_store_reports_worker
      return unless pipeline.default_branch?

      Gitlab::Redis::SharedState.with do |redis|
        redis.set(Security::StoreSecurityReportsByProjectWorker.cache_key(project_id: project.id), pipeline.id)
      end

      Security::StoreSecurityReportsByProjectWorker.perform_async(project.id)
    end

    def schedule_scan_security_report_secrets_worker
      ScanSecurityReportSecretsWorker.perform_async(pipeline.id) if revoke_secret_detection_token?
    end

    def revoke_secret_detection_token?
      pipeline.project.public? &&
        ::Gitlab::CurrentSettings.secret_detection_token_revocation_enabled? &&
        secret_detection_scans_found?
    end

    def secret_detection_scans_found?
      pipeline.security_scans.by_scan_types(:secret_detection).any?
    end

    def sync_findings_to_approval_rules
      return unless project.licensed_feature_available?(:security_orchestration_policies)

      Security::ScanResultPolicies::SyncFindingsToApprovalRulesWorker.perform_async(pipeline.id)
    end
  end
end
