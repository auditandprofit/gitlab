# frozen_string_literal: true

module Security
  class MergeRequestSecurityReportGenerationService
    include Gitlab::Utils::StrongMemoize

    DEFAULT_FINDING_STATE = 'detected'
    ALLOWED_REPORT_TYPES = %w[sast secret_detection container_scanning
      dependency_scanning dast coverage_fuzzing api_fuzzing].freeze

    InvalidReportTypeError = Class.new(ArgumentError)

    def self.execute(merge_request, report_type)
      new(merge_request, report_type).execute
    end

    def initialize(merge_request, report_type)
      @merge_request = merge_request
      @report_type = report_type
    end

    def execute
      return report unless report_available?

      set_states_and_severities_of!(added_findings)
      set_states_and_severities_of!(fixed_findings)

      report
    end

    private

    attr_reader :merge_request, :report_type

    def report_available?
      report[:status] == :parsed
    end

    def set_states_and_severities_of!(findings)
      findings.each do |finding|
        vulnerability_data = existing_vulnerabilities[finding['uuid']]
        finding['state'] = vulnerability_data&.dig(:state) || DEFAULT_FINDING_STATE
        finding['severity'] = vulnerability_data&.dig(:severity) || finding['severity']
        finding['severity_override'] = vulnerability_data&.dig(:severity_override)
      end
    end

    def existing_vulnerabilities
      @existing_vulnerabilities ||=
        Vulnerability
        .with_findings_by_uuid(finding_uuids)
        .with_latest_severity_override
        .to_h do |vulnerability|
          [
            vulnerability.finding.uuid,
            {
              severity: vulnerability.severity,
              state: vulnerability.state,
              id: vulnerability.id,
              severity_override: latest_severity_override(vulnerability)
            }
          ]
        end
    end

    def latest_severity_override(vulnerability)
      latest_override = vulnerability.latest_severity_override
      return unless latest_override

      latest_override.as_json(
        only: [:vulnerability_id, :created_at, :original_severity, :new_severity],
        methods: [:author_data]
      )
    end

    def finding_uuids
      (added_findings + fixed_findings).pluck('uuid') # rubocop:disable CodeReuse/ActiveRecord
    end

    def added_findings
      @added_findings ||= report.dig(:data, 'added')
    end

    def fixed_findings
      @fixed_findings ||= report.dig(:data, 'fixed')
    end

    strong_memoize_attr def report
      validate_report_type!

      case report_type
      when 'sast'
        merge_request.compare_sast_reports(nil)
      when 'secret_detection'
        merge_request.compare_secret_detection_reports(nil)
      when 'container_scanning'
        merge_request.compare_container_scanning_reports(nil)
      when 'dependency_scanning'
        merge_request.compare_dependency_scanning_reports(nil)
      when 'dast'
        merge_request.compare_dast_reports(nil)
      when 'coverage_fuzzing'
        merge_request.compare_coverage_fuzzing_reports(nil)
      when 'api_fuzzing'
        merge_request.compare_api_fuzzing_reports(nil)
      end
    end

    def validate_report_type!
      raise InvalidReportTypeError unless ALLOWED_REPORT_TYPES.include?(report_type)
    end
  end
end
