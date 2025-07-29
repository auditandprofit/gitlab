# frozen_string_literal: true

module Gitlab
  module Ci
    module Reports
      module Security
        class SecurityFindingsReportsComparer
          include Gitlab::Utils::StrongMemoize

          attr_reader :base_report, :head_report, :project, :added_findings, :fixed_findings

          ACCEPTABLE_REPORT_AGE = 1.week
          MAX_FINDINGS_COUNT = 25
          VULNERABILITY_FILTER_METRIC_KEY = :vulnerability_report_branch_comparison

          def initialize(project, base_report, head_report)
            @base_report = base_report
            @head_report = head_report
            @project = project

            @added_findings = []
            @fixed_findings = []
            calculate_changes
          end

          def base_report_created_at
            base_report.created_at
          end

          def head_report_created_at
            head_report.created_at
          end

          def base_report_out_of_date
            return false unless base_report.created_at

            base_report.created_at.before?(ACCEPTABLE_REPORT_AGE.ago)
          end

          # rubocop:disable CodeReuse/ActiveRecord -- pluck method requires this
          def undismissed_on_default_branch(findings, limit)
            uuids = findings.map(&:uuid)

            query = Vulnerability
              .present_on_default_branch.with_findings_by_uuid_and_state(uuids, :dismissed)
              .limit(limit)

            dismissed_uuids = ::Gitlab::Metrics.measure(VULNERABILITY_FILTER_METRIC_KEY) do
              query.pluck(:uuid)
            end.to_set

            findings.reject { |f| dismissed_uuids.include?(f.uuid) }
          end

          def process_findings(findings)
            unchecked_findings = findings.each_slice(MAX_FINDINGS_COUNT).to_a
            undismissed_findings = []
            limit = MAX_FINDINGS_COUNT

            while unchecked_findings.any? && limit > 0
              undismissed_findings += undismissed_on_default_branch(unchecked_findings.shift, limit)
              limit -= undismissed_findings.size
            end

            undismissed_findings
          end
          # rubocop:enable CodeReuse/ActiveRecord

          def added
            process_findings(added_findings)
          end
          strong_memoize_attr :added

          def fixed
            process_findings(fixed_findings)
          end
          strong_memoize_attr :fixed

          def errors
            []
          end
          strong_memoize_attr :errors

          def warnings
            []
          end
          strong_memoize_attr :warnings

          private

          def calculate_changes
            base_findings = base_report.findings
            head_findings = head_report.findings

            base_findings_uuids_set = base_findings.map(&:uuid).to_set
            head_findings_uuids_set = head_findings.map(&:uuid).to_set

            @added_findings = head_findings.reject { |f| base_findings_uuids_set.include?(f.uuid) }
            @fixed_findings = base_findings.reject do |finding|
              finding.requires_manual_resolution? || head_findings_uuids_set.include?(finding.uuid)
            end
          end
        end
      end
    end
  end
end
