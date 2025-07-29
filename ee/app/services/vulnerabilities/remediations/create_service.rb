# frozen_string_literal: true

module Vulnerabilities
  module Remediations
    class CreateService
      include BaseServiceUtility
      include ::Gitlab::Utils::StrongMemoize

      def initialize(project:, diff:, findings:, summary:)
        @project = project
        @diff = diff
        @findings = findings
        @summary = summary || "Vulnerability Remediation"
      end

      def execute
        return error_response("No findings given to relate remediation to") unless @findings.present?

        remediation = Vulnerabilities::Remediation.create(
          project: @project,
          file: Tempfile.new.tap { |f| f.write(@diff) },
          summary: @summary,
          findings: @findings,
          checksum: Digest::SHA256.hexdigest(@diff)
        )

        remediation.save ? success_response(remediation) : error_response("Remediation creation failed")
      end

      private

      def error_response(message)
        ServiceResponse.error(message: message)
      end

      def success_response(remediation)
        ServiceResponse.success(payload: { remediation: remediation })
      end
    end
  end
end
