# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class PolicyViolationComment
      include Rails.application.routes.url_helpers
      include Gitlab::Utils::StrongMemoize

      MESSAGE_HEADER = '<!-- policy_violation_comment -->'
      VIOLATED_REPORTS_HEADER_PATTERN = /<!-- violated_reports: ([a-z_,]+)/
      OPTIONAL_APPROVALS_HEADER_PATTERN = /<!-- optional_approvals: ([a-z_,]+)/
      REPORT_TYPES = {
        license_scanning: 'license_scanning',
        scan_finding: 'scan_finding',
        any_merge_request: 'any_merge_request'
      }.freeze

      MORE_VIOLATIONS_DETECTED = 'More violations have been detected in addition to the list above.'
      VIOLATIONS_BLOCKING_TITLE = ':warning: **Violations blocking this merge request**'
      VIOLATIONS_DETECTED_TITLE = ':warning: **Violations detected in this merge request**'

      attr_reader :reports, :optional_approval_reports, :existing_comment, :merge_request

      def initialize(existing_comment, merge_request)
        @existing_comment = existing_comment
        @reports = Set.new
        @optional_approval_reports = Set.new
        @merge_request = merge_request

        return unless existing_comment

        parse_reports
      end

      def add_report_type(report_type, requires_approval)
        add_optional_approval_report(report_type) unless requires_approval
        @reports = (reports + [report_type]) & REPORT_TYPES.values
      end

      def add_optional_approval_report(report_type)
        @optional_approval_reports = (optional_approval_reports + [report_type]) & REPORT_TYPES.values
      end

      def remove_report_type(report_type)
        @optional_approval_reports -= [report_type]
        @reports -= [report_type]
      end

      def clear_report_types
        @optional_approval_reports.clear
        @reports.clear
      end

      def body
        return if existing_comment.nil? && reports.empty?

        [MESSAGE_HEADER, body_message].join("\n")
      end
      strong_memoize_attr :body

      private

      delegate :project, to: :merge_request

      def parse_reports
        parse_report_list(VIOLATED_REPORTS_HEADER_PATTERN) { |report_type| add_report_type(report_type, true) }
        parse_report_list(OPTIONAL_APPROVALS_HEADER_PATTERN) { |report_type| add_optional_approval_report(report_type) }
      end

      def parse_report_list(pattern, &block)
        match = existing_comment.note.match(pattern)
        match[1].split(',').each(&block) if match
      end

      def fixed_note_body
        'Security policy violations have been resolved.'
      end

      def reports_header
        optional_approvals_sorted_list = optional_approval_reports.sort.join(',')

        <<~MARKDOWN
        <!-- violated_reports: #{reports.sort.join(',')} -->
        #{"<!-- optional_approvals: #{optional_approvals_sorted_list} -->" if optional_approval_reports.any?}
        MARKDOWN
      end

      def body_message
        return fixed_note_body if reports.empty?

        [
          summary,
          newly_introduced_violations,
          previously_existing_violations,
          any_merge_request_commits,
          license_scanning_violations,
          error_messages,
          comparison_pipelines,
          additional_info
        ].compact.join("\n")
      end

      def blocking_violations?
        reports != optional_approval_reports && details.fail_closed_policies.present?
      end

      def details
        ::Security::ScanResultPolicies::PolicyViolationDetails.new(merge_request)
      end
      strong_memoize_attr :details

      def summary
        <<~MARKDOWN
        #{reports_header}
        #{merge_request.author.name}, this merge request has policy violations and errors.
        #{blocking_violations? ? "**To unblock this merge request, fix these items:**\n" : ''}
        #{violation_summary}
        #{
          if blocking_violations?
            "If you think these items shouldn't be violations, ask eligible approvers of each policy to approve this merge request."
          else
            'Consider including optional reviewers based on the policy rules in the MR widget.'
          end
        }
        #{
          if details.fail_open_policies.any?
            "\nThe following policies enforced on your project were skipped because they are configured to fail open: " \
              "#{details.fail_open_policies.join(', ')}.\n\n#{array_to_list(details.fail_open_messages)}"
          end
        }

        #{
          if [newly_introduced_violations, previously_existing_violations, any_merge_request_commits].any?(&:present?)
            blocking_violations? ? VIOLATIONS_BLOCKING_TITLE : VIOLATIONS_DETECTED_TITLE
          else
            ''
          end
        }
        MARKDOWN
      end

      def violation_summary
        fail_closed_policies = details.fail_closed_policies
        return if fail_closed_policies.blank?

        any_merge_request_policies = details.fail_closed_policies(:any_merge_request)
        license_scanning_policies = details.fail_closed_policies(:license_scanning)
        errors = details.errors
        summary = ["Resolve all violations in the following merge request approval policies: " \
          "#{fail_closed_policies.join(', ')}."]

        if any_merge_request_policies.present?
          summary << "Acquire approvals from eligible approvers defined in the following " \
            "merge request approval policies: #{any_merge_request_policies.join(', ')}."
        end

        if license_scanning_policies.present? && license_scanning_violations.present?
          summary << ("Remove all denied licenses identified by the following merge request approval policies: " \
            "#{license_scanning_policies.join(', ')}")
        end

        summary << 'Resolve the errors and re-run the pipeline.' if errors.present?

        array_to_list(summary)
      end

      def newly_introduced_violations
        scan_finding_violations(details.new_scan_finding_violations, 'This merge request introduces these violations')
      end
      strong_memoize_attr :newly_introduced_violations

      def previously_existing_violations
        scan_finding_violations(details.previous_scan_finding_violations, 'Previously existing vulnerabilities')
      end
      strong_memoize_attr :previously_existing_violations

      def scan_finding_violations(violations, title)
        list = violations.map do |violation|
          build_scan_finding_violation_line(violation)
        end
        return if list.empty?

        <<~MARKDOWN
        ---

        #{title}:

        #{violations_list(list)}
        MARKDOWN
      end

      def license_scanning_violations
        list = details.license_scanning_violations.map do |violation|
          dependencies = violation.dependencies
          "1. #{violation.url.present? ? "[#{violation.license}](#{violation.url})" : violation.license}: " \
            "Used by #{dependencies.first(Security::ScanResultPolicyViolation::MAX_VIOLATIONS).join(', ')}" \
            "#{dependencies.size > Security::ScanResultPolicyViolation::MAX_VIOLATIONS ? ', …and more' : ''}"
        end
        return if list.empty?

        <<~MARKDOWN
        :warning: **Out-of-policy licenses:**

        #{violations_list(list)}
        MARKDOWN
      end

      def build_scan_finding_violation_line(violation)
        line = "1."
        line += " #{violation.severity.capitalize} **·**" if violation.severity
        line += " #{violation.name}" if violation.name

        if violation.path.present?
          location = violation.location
          start_line = location[:start_line]
          line += " **·** [#{start_line.present? ? "Line #{start_line} " : ''}#{location[:file]}](#{violation.path})"
        end

        line += " (#{violation.report_type.humanize})" if violation.report_type
        line
      end

      def any_merge_request_commits
        list = details.any_merge_request_violations.flat_map do |violation|
          next unless violation.commits.is_a?(Array)

          violation.commits.map { |commit| "1. [`#{commit}`](#{project_commit_url(project, commit)})" }
        end.compact
        return if list.empty?

        <<~MARKDOWN
        ---

        Unsigned commits:

        #{violations_list(list)}
        MARKDOWN
      end
      strong_memoize_attr :any_merge_request_commits

      def violations_list(list)
        [
          list.first(Security::ScanResultPolicyViolation::MAX_VIOLATIONS).join("\n"),
          list.size > Security::ScanResultPolicyViolation::MAX_VIOLATIONS ? "\n#{MORE_VIOLATIONS_DETECTED}" : nil
        ].compact.join("\n")
      end

      def error_messages
        errors = details.errors
        return if errors.blank?

        <<~MARKDOWN
        :exclamation: **Errors**

        #{errors.map { |error| "- #{error.message}" }.join("\n")}
        MARKDOWN
      end

      def additional_info
        return unless Feature.enabled?(:security_policy_approval_warn_mode, project) && details.warn_mode_policies.any?

        <<~MARKDOWN
        :information: **Additional information**

        Review the following policies to understand requirements and identify policy owners for support:

        #{details.warn_mode_policies.map { |policy| "- [#{policy.name}](#{policy.edit_path})" }.join("\n")}
        MARKDOWN
      end

      def comparison_pipelines
        pipelines = details.comparison_pipelines
        return if pipelines.blank?

        render_title = pipelines.many? # rubocop:disable CodeReuse/ActiveRecord -- pipelines is an array
        <<~MARKDOWN
        :information_source: **Comparison pipelines**

        #{pipelines.map { |pipeline| build_comparison_pipelines_info(pipeline, render_title) }.join("\n")}
        MARKDOWN
      end

      def build_comparison_pipelines_info(pipeline, render_title)
        pipeline_to_link = ->(id) { "[##{id}](#{project_pipeline_url(project, id)})" }
        source_pipeline_links = pipeline.source.map(&pipeline_to_link)
        target_pipeline_links = pipeline.target.map(&pipeline_to_link)

        info = <<~MARKDOWN
        - Target branch (`#{merge_request.target_branch}`): #{target_pipeline_links.join(', ').presence || 'None'}
        - Source branch (`#{merge_request.source_branch}`): #{source_pipeline_links.join(', ').presence || 'None'}
        MARKDOWN

        [(pipeline.report_type.humanize if render_title), info].compact.join("\n")
      end

      def array_to_list(array)
        array.map { |item| "- #{item}" }.join("\n")
      end
    end
  end
end
