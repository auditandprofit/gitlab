# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class PolicyViolationDetails
      include Gitlab::Utils::StrongMemoize

      Violation = Struct.new(:report_type, :name, :scan_result_policy_id, :data, :warning, :status, :warn_mode,
        :security_policy, keyword_init: true)
      ViolationError = Struct.new(:report_type, :error, :data, :message, :warning, keyword_init: true)
      ScanFindingViolation = Struct.new(:name, :report_type, :severity, :location, :path, keyword_init: true)
      AnyMergeRequestViolation = Struct.new(:name, :commits, keyword_init: true)
      LicenseScanningViolation = Struct.new(:license, :dependencies, :url, keyword_init: true)
      ComparisonPipelines = Struct.new(:report_type, :source, :target, keyword_init: true)

      ERROR_UNKNOWN = 'UNKNOWN'
      # Hash of error messages mapping by key
      # Each key can have different messages per report_type and define ERROR_UNKNOWN as a fallback
      ERROR_MESSAGES = {
        'UNKNOWN' => 'Unknown error: %{error}',
        'SCAN_REMOVED' => 'There is a mismatch between the scans of the source and target pipelines. ' \
                          'The following scans are missing: %{scans}',
        'TARGET_PIPELINE_MISSING' => 'Pipeline configuration error: SBOM reports required by policy `%{policy}` ' \
          'could not be found on the target branch.',
        'ARTIFACTS_MISSING' => {
          'scan_finding' => 'Pipeline configuration error: Security reports required by policy `%{policy}` ' \
                            'could not be found.',
          'license_scanning' => 'Pipeline configuration error: SBOM reports required by policy `%{policy}` ' \
                                'could not be found.',
          ERROR_UNKNOWN => 'Pipeline configuration error: Artifacts required by policy `%{policy}` ' \
                                 'could not be found (%{report_type}).'
        },
        'EVALUATION_SKIPPED' => 'Policy `%{policy}` could not be evaluated within the specified timeframe ' \
          'and, as a result, approvals are required for the policy. ' \
          'Ensure that scanners are present in the latest pipeline.',
        'PIPELINE_FAILED' => 'Policy `%{policy}` could not be evaluated because the latest pipeline failed. ' \
          'Ensure that the pipeline is configured properly and the scanners are present.'
      }.freeze

      # These messages correspond to the possible errors above and are shown when a policy is configured to fail open
      FAIL_OPEN_MESSAGES = {
        'SCAN_REMOVED' => 'Confirm that all scanners from the target branch are present on the source branch.',
        'TARGET_PIPELINE_MISSING' => 'Confirm that dependency scanning is properly configured on the target branch ' \
          'pipeline and is producing results. License scanning depends on SBOM reports.',
        'ARTIFACTS_MISSING' => {
          'scan_finding' => 'Confirm that scanners are properly configured and producing results. ' \
            'Vulnerability detection depends on successful execution of security scan jobs in the ' \
            'target and source branches.',
          'license_scanning' => 'Confirm that dependency scanning is properly configured and is producing results. ' \
            'License detection depends on SBOM reports produced by the dependency scanning job ' \
            'in the target and source branches.'
        }
      }.freeze

      def initialize(merge_request)
        @merge_request = merge_request
      end

      def violations
        merge_request.scan_result_policy_violations.filter_map do |violation|
          rule = scan_result_policy_rules[violation.scan_result_policy_id]
          next if rule.blank? # there may be a race condition situation where rule is missing

          Violation.new(
            report_type: rule.report_type,
            name: rule.policy_name,
            scan_result_policy_id: rule.scan_result_policy_id,
            data: violation.violation_data,
            warning: violation.warn?,
            status: violation.status,
            security_policy: violation.security_policy,
            warn_mode: violation.security_policy&.warn_mode?
          )
        end
      end
      strong_memoize_attr :violations

      def violations_count
        new_scan_finding_violations.count +
          previous_scan_finding_violations.count +
          license_scanning_violations.count +
          any_merge_request_violations.count
      end

      def fail_closed_policies(report_type = nil)
        filtered_violations = violations.reject(&:warning)

        if Feature.enabled?(:security_policy_approval_warn_mode, project)
          filtered_violations = filtered_violations.reject(&:warn_mode)
        end

        if report_type
          filtered_violations = filtered_violations.select { |violation| violation.report_type == report_type.to_s }
        end

        filtered_violations.pluck(:name).compact.uniq.sort # rubocop:disable CodeReuse/ActiveRecord -- Pluck used on hashes
      end

      def fail_open_policies
        filtered_violations = violations.select(&:warning)

        if Feature.enabled?(:security_policy_approval_warn_mode, project)
          filtered_violations = filtered_violations.reject(&:warn_mode)
        end

        filtered_violations.pluck(:name).compact.uniq.sort # rubocop:disable CodeReuse/ActiveRecord -- Pluck used on hashes
      end
      strong_memoize_attr :fail_open_policies

      def warn_mode_policies
        violations.select(&:warn_mode).filter_map(&:security_policy)
      end

      def new_scan_finding_violations
        uuids = extract_from_violation_data(%w[violations scan_finding uuids newly_detected])
        newly_detected_violations(uuids, extract_from_violation_data(%w[context pipeline_ids]))
      end
      strong_memoize_attr :new_scan_finding_violations

      def previous_scan_finding_violations
        uuids = extract_from_violation_data(%w[violations scan_finding uuids previously_existing])
        previously_existing_violations(uuids)
      end
      strong_memoize_attr :previous_scan_finding_violations

      def license_scanning_violations
        merged_by_license = violations.each_with_object({}) do |violation, result|
          license_map = violation.data&.dig('violations', 'license_scanning')
          next unless license_map

          license_map.each { |license, dependencies| (result[license] ||= Set.new).merge(dependencies) }
        end

        license_spdx_map = license_spdx(merged_by_license.keys)
        merged_by_license.map do |license, dependencies|
          LicenseScanningViolation.new(
            license: license,
            dependencies: dependencies.sort.to_a,
            url: Gitlab::LicenseScanning::PackageLicenses.url_for(license_spdx_map[license])
          )
        end
      end
      strong_memoize_attr :license_scanning_violations

      def any_merge_request_violations
        violations.select { |violation| violation.report_type == 'any_merge_request' }.flat_map do |violation|
          AnyMergeRequestViolation.new(
            name: violation.name,
            commits: violation.data&.dig('violations', 'any_merge_request', 'commits')
          )
        end
      end
      strong_memoize_attr :any_merge_request_violations

      def errors
        violations.flat_map do |violation|
          errors = violation.data&.dig('errors') || []
          errors.map do |error|
            ViolationError.new(
              report_type: violation.report_type,
              error: ERROR_MESSAGES.key?(error['error']) ? error['error'] : ERROR_UNKNOWN,
              data: error.except('error'),
              message: error_message(violation, error),
              warning: violation.warning
            )
          end
        end
      end
      strong_memoize_attr :errors

      def fail_open_messages
        errors.select(&:warning).filter_map do |error|
          message = FAIL_OPEN_MESSAGES[error.error]
          message.is_a?(Hash) ? message[error.report_type] : message
        end
      end
      strong_memoize_attr :fail_open_messages

      def comparison_pipelines
        violations.group_by(&:report_type).filter_map do |report_type, report_violations|
          source_pipelines = extract_from_violation_data(%w[context pipeline_ids], report_violations)
          target_pipelines = extract_from_violation_data(%w[context target_pipeline_ids], report_violations)
          next if source_pipelines.blank? && target_pipelines.blank?

          ComparisonPipelines.new(
            report_type: report_type,
            source: source_pipelines,
            target: target_pipelines
          )
        end
      end
      strong_memoize_attr :comparison_pipelines

      private

      attr_accessor :merge_request

      delegate :project, to: :merge_request

      def pipeline
        merge_request.diff_head_pipeline
      end
      strong_memoize_attr :pipeline

      def scan_result_policy_rules
        merge_request.approval_rules.with_scan_result_policy_read.index_by(&:scan_result_policy_id)
      end
      strong_memoize_attr :scan_result_policy_rules

      def previously_existing_violations(uuids)
        return [] if uuids.blank?

        Security::ScanResultPolicies::VulnerabilitiesFinder.new(project,
          { limit: uuids_limit, uuids: uuids.first(uuids_limit) }).execute.map do |vulnerability|
          finding = vulnerability.finding
          ScanFindingViolation.new(
            report_type: finding.report_type,
            severity: finding.severity,
            path: vulnerability.present.location_link,
            location: finding.location.with_indifferent_access,
            name: finding.name
          )
        end
      end

      def newly_detected_violations(uuids, related_pipeline_ids)
        return [] if uuids.blank?

        Security::ScanResultPolicies::FindingsFinder.new(project, pipeline,
          { related_pipeline_ids: related_pipeline_ids, uuids: uuids.first(uuids_limit) }).execute
        .uniq(&:uuid).map do |finding|
          ScanFindingViolation.new(
            report_type: finding.report_type,
            severity: finding.severity,
            path: finding.finding_data.present? ? finding.present.blob_url : nil,
            location: finding.finding_data.present? ? finding.location : nil,
            name: finding.finding_data.present? ? finding.name : nil
          )
        end
      end

      def uuids_limit
        Security::ScanResultPolicyViolation::MAX_VIOLATIONS + 1
      end

      def license_spdx(licenses)
        licenses = ::Gitlab::SPDX::Catalogue.latest_active_licenses.select do |spdx_license|
          licenses.include?(spdx_license.name)
        end

        licenses.to_h do |license|
          [license.name, license.id]
        end
      end

      def error_message(violation, error)
        error_key = error['error']
        params = case error_key
                 when 'SCAN_REMOVED'
                   { scans: error['missing_scans']&.map(&:humanize)&.join(', ') }
                 when 'ARTIFACTS_MISSING'
                   { policy: violation.name, report_type: violation.report_type }
                 else
                   { error: error_key, policy: violation.name }
                 end

        message_for_key = ERROR_MESSAGES[error_key] || ERROR_MESSAGES[ERROR_UNKNOWN]
        if message_for_key.is_a?(Hash)
          message_for_key = message_for_key[violation.report_type] || message_for_key[ERROR_UNKNOWN]
        end

        format(message_for_key, **params)
      end

      # Extract data for given keys from violations
      #
      # @param [Array<String>] keys path to the data
      # @return [Set] extracted data
      def extract_from_violation_data(keys, violations_list = violations)
        violations_list.each_with_object(Set.new) do |violation, result|
          result.merge(violation.data&.dig(*keys) || [])
        end
      end
    end
  end
end
