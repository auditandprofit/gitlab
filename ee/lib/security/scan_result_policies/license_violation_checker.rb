# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class LicenseViolationChecker
      def initialize(project, report, target_branch_report)
        @project = project
        @report = report
        @target_branch_report = target_branch_report
      end

      ## Checks if a policy rule violates the following conditions:
      ##   - If license_states has `newly_detected`, check for newly detected dependency
      ##     with license type violating the policy.
      ##   - If match_on_inclusion_license is false, any detected licenses that does not match
      ##     the licenses from `license_types` should require approval
      def execute(scan_result_policy_read)
        comparison_report = scan_result_policy_read.newly_detected? ? report : target_branch_report

        software_license_policies = software_license_policies(scan_result_policy_read)
        licenses_from_policy = extend_from_report(comparison_report, software_license_policies)
        licenses_from_report = join_ids_and_names(
          comparison_report.licenses.filter_map(&:id), comparison_report.license_names
        )

        license_ids, license_names = licenses_to_check(scan_result_policy_read)

        if scan_result_policy_read.match_on_inclusion_license
          all_denied_licenses = licenses_from_policy
          policy_denied_license_names = all_denied_licenses & licenses_from_report
          violates_license_policy = violates_db_licenses?(software_license_policies, license_ids, license_names.to_set)
        else
          # when match_on_inclusion_license is false, only the licenses mentioned in the policy are allowed
          all_denied_licenses = (licenses_from_report - licenses_from_policy).uniq
          comparison_licenses = join_ids_and_names(license_ids, license_names)
          policy_denied_license_names = (comparison_licenses - licenses_from_policy).uniq
          violates_license_policy = policy_denied_license_names.present?
        end

        if violates_license_policy
          denied_licenses_with_dependencies = licenses_with_dependencies(comparison_report, policy_denied_license_names)
        end

        # when there are no license violations, but new dependency with denied licenses is added, require approval
        if scan_result_policy_read.newly_detected?
          new_license_dependency_map = new_dependencies_with_denied_licenses(all_denied_licenses)
          denied_licenses_with_dependencies = new_license_dependency_map if new_license_dependency_map.present?
        end

        denied_licenses_with_dependencies
      end

      private

      attr_reader :project, :report, :target_branch_report

      def software_license_policies(scan_result_policy_read)
        project
          .software_license_policies
          .including_custom_license
          .for_scan_result_policy_read(scan_result_policy_read.id)
      end

      def violates_db_licenses?(software_license_policies, ids, names)
        spdx_ids_for_license_names = SoftwareLicensePolicy.latest_active_licenses_by_name(names).pluck(:id) # rubocop:disable CodeReuse/ActiveRecord -- Not AR object
        spdx_ids = (ids + spdx_ids_for_license_names).to_set

        policies = software_license_policies.select do |policy|
          spdx_ids.include?(policy.spdx_identifier) || names.include?(policy.custom_software_license&.name)
        end

        policies.present?
      end

      def licenses_to_check(scan_result_policy_read)
        only_newly_detected = scan_result_policy_read.license_states == [ApprovalProjectRule::NEWLY_DETECTED]

        if only_newly_detected
          diff = target_branch_report.diff_with(report)
          license_names = diff[:added].map(&:name)
          license_ids = diff[:added].filter_map(&:id)
        elsif scan_result_policy_read.newly_detected?
          license_names = report.license_names
          license_ids = report.licenses.filter_map(&:id)
        else
          license_names = target_branch_report.license_names
          license_ids = target_branch_report.licenses.filter_map(&:id)
        end

        [license_ids, license_names]
      end

      def join_ids_and_names(ids, names)
        (ids + names).compact.uniq
      end

      def licenses_matching_name_or_id(comparison_report, licenses)
        comparison_report.licenses.select { |license| licenses.include?(license.name) || licenses.include?(license.id) }
      end

      def licenses_with_dependencies(comparison_report, licenses)
        licenses_matching_name_or_id(comparison_report, licenses).to_h do |license|
          [license.name, license.dependencies.map(&:name)]
        end
      end

      # Licenses from policies may match either spdx or name.
      # If we find either in the report, we take also the other value into comparison
      def extend_from_report(comparison_report, software_license_policies)
        licenses = join_ids_and_names(
          software_license_policies.filter_map(&:spdx_identifier),
          software_license_policies.filter_map(&:name)
        )

        licenses += licenses_matching_name_or_id(comparison_report, licenses).flat_map do |license|
          [license.id, license.name]
        end
        licenses.compact.uniq
      end

      def new_dependencies_with_denied_licenses(denied_licenses)
        licenses_with_dependencies(report, denied_licenses)
          .transform_values { |dependency_names| dependency_names & newly_introduced_dependency_names }
          .select { |_license, dependency_names| dependency_names.present? }
      end

      def newly_introduced_dependency_names
        report.dependency_names - target_branch_report.dependency_names
      end
    end
  end
end
