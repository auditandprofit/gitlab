# frozen_string_literal: true

module EE
  module Enums
    module Ci
      module JobArtifact
        extend ActiveSupport::Concern

        SECURITY_REPORT_FILE_TYPES = %w[sast secret_detection dependency_scanning container_scanning
          cluster_image_scanning dast coverage_fuzzing api_fuzzing].freeze

        SECURITY_REPORT_AND_CYCLONEDX_REPORT_FILE_TYPES = (SECURITY_REPORT_FILE_TYPES | %w[cyclonedx]).freeze

        EE_REPORT_FILE_TYPES = {
          license_scanning: %w[license_scanning].freeze,
          dependency_list: %w[dependency_scanning].freeze,
          metrics: %w[metrics].freeze,
          container_scanning: %w[container_scanning].freeze,
          cluster_image_scanning: %w[cluster_image_scanning].freeze,
          dast: %w[dast].freeze,
          requirements: %w[requirements].freeze,
          requirements_v2: %w[requirements_v2].freeze,
          coverage_fuzzing: %w[coverage_fuzzing].freeze,
          api_fuzzing: %w[api_fuzzing].freeze,
          browser_performance: %w[browser_performance performance].freeze,
          sbom: %w[cyclonedx].freeze
        }.freeze

        def self.security_report_file_types
          SECURITY_REPORT_FILE_TYPES
        end

        def self.security_report_and_cyclonedx_report_file_types
          SECURITY_REPORT_AND_CYCLONEDX_REPORT_FILE_TYPES
        end

        def self.ee_report_file_types
          EE_REPORT_FILE_TYPES
        end
      end
    end
  end
end
