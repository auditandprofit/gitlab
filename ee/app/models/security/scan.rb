# frozen_string_literal: true

module Security
  class Scan < ::SecApplicationRecord
    include CreatedAtFilterable

    self.table_name = 'security_scans'

    validates :build_id, presence: true
    validates :scan_type, presence: true
    validates :info, json_schema: { filename: 'security_scan_info' }

    belongs_to :build, class_name: 'Ci::Build'
    belongs_to :project
    belongs_to :pipeline, class_name: 'Ci::Pipeline'

    has_many :findings, inverse_of: :scan
    has_one :partial_scan, class_name: 'Vulnerabilities::PartialScan'

    enum :scan_type, {
      sast: 1,
      dependency_scanning: 2,
      container_scanning: 3,
      dast: 4,
      secret_detection: 5,
      coverage_fuzzing: 6,
      api_fuzzing: 7,
      cluster_image_scanning: 8
    }

    declarative_enum Security::ScanStatusEnum

    scope :by_scan_types, ->(scan_types) { where(scan_type: sanitize_scan_types(scan_types)) }
    scope :by_project, ->(project) { where(project: project) }
    scope :distinct_scan_types, -> { select(:scan_type).distinct.pluck(:scan_type) }
    scope :by_pipeline_ids, ->(pipeline_ids) { where(pipeline_id: pipeline_ids) }
    scope :latest, -> { where(latest: true) }
    scope :latest_successful, -> { latest.succeeded }
    scope :by_build_ids, ->(build_ids) { where(build_id: build_ids) }
    scope :without_errors, -> { where("jsonb_array_length(COALESCE(info->'errors', '[]'::jsonb)) = 0") }
    scope :stale, -> { where("created_at < ?", stale_after.ago).where.not(status: :purged) }
    scope :ordered_by_created_at_and_id, -> { order(:created_at, :id) }
    scope :with_warnings, -> { where("jsonb_array_length(COALESCE(info->'warnings', '[]'::jsonb)) > 0") }
    scope :with_errors, -> { where("jsonb_array_length(COALESCE(info->'errors', '[]'::jsonb)) > 0") }
    scope :not_in_terminal_state, -> { where.not(status: Security::ScanStatusEnum::TERMINAL_STATUSES) }

    delegate :name, to: :build
    delegate :mode, to: :partial_scan, prefix: true, allow_nil: true
    alias_attribute :type, :scan_type

    before_save :ensure_project_id_pipeline_id

    def self.sanitize_scan_types(given_types)
      scan_types.keys & Array(given_types).map(&:to_s)
    end

    def self.pipeline_ids(project, scan_type)
      by_scan_types(scan_type).by_project(project).succeeded.pluck(:pipeline_id)
    end

    def self.projects_with_scans(project_ids)
      Security::Scan.where(project_id: project_ids).distinct.pluck(:project_id)
    end

    # rubocop:disable Gitlab/AvoidGitlabInstanceChecks -- This is not a feature check
    def self.stale_after
      if Gitlab.com?
        30.days
      else
        90.days
      end
    end
    # rubocop:enable Gitlab/AvoidGitlabInstanceChecks

    # If the record is created 3 months ago and purged,
    # it means that all the previous records must be purged
    # as well so the related findings can be dropped.
    def findings_can_be_purged?
      created_at < self.class.stale_after.ago && purged?
    end

    def has_warnings?
      processing_warnings.present?
    end

    def processing_warnings
      info.fetch('warnings', [])
    end

    def processing_warnings=(warnings)
      info['warnings'] = warnings
    end

    def has_errors?
      processing_errors.present?
    end

    def processing_errors
      info.fetch('errors', [])
    end

    def processing_errors=(errors)
      info['errors'] = errors
    end

    def add_processing_error!(error)
      info['errors'] = processing_errors.push(error.stringify_keys)

      save!
    end

    # Returns the findings from the source report
    def report_findings
      @report_findings ||= security_report&.findings.to_a
    end

    def report_primary_identifiers
      @report_primary_identifiers ||= security_report&.primary_identifiers
    end

    def remediations_proxy
      @remediations_proxy ||= RemediationsProxy.new(job_artifact&.file)
    end

    def scanner
      project.vulnerability_scanners.find_by_external_id(security_report&.scanner&.external_id)
    end

    private

    def security_report
      job_artifact&.security_report
    end

    def job_artifact
      build.job_artifacts.find_by_file_type(scan_type)
    end

    def ensure_project_id_pipeline_id
      self.project_id ||= build.project_id
      self.pipeline_id ||= build.commit_id
    end
  end
end
