# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class UpdateLicenseApprovalsService
      include Gitlab::Utils::StrongMemoize
      include ::Security::ScanResultPolicies::PolicyLogger
      include ::Security::ScanResultPolicies::RelatedPipelines

      def initialize(merge_request, pipeline, preexisting_states = false)
        @merge_request = merge_request
        @pipeline = pipeline
        @preexisting_states = preexisting_states
      end

      def execute
        return if merge_request.merged?

        approval_rules = merge_request
                           .approval_rules
                           .report_approver
                           .license_scanning
                           .with_scan_result_policy_read
                           .including_scan_result_policy_read
        return if approval_rules.empty?

        if !preexisting_states && !scanner.results_available?
          log_update_approval_rule('No SBOM reports found for the pipeline')
          return
        end

        filtered_rules = filter_approval_rules(approval_rules)
        return if filtered_rules.empty?

        evaluate_rules(filtered_rules)
        evaluation.save
      end

      private

      attr_reader :merge_request, :pipeline, :preexisting_states

      delegate :project, to: :merge_request

      def filter_approval_rules(approval_rules)
        rule_filter = ->(approval_rule) { approval_rule.scan_result_policy_read.newly_detected? }

        preexisting_states ? approval_rules.reject(&rule_filter) : approval_rules.select(&rule_filter)
      end

      def evaluate_rules(license_approval_rules)
        log_update_approval_rule('Evaluating license_scanning rules from approval policies', **validation_context)
        license_approval_rules.each do |approval_rule|
          # We only error for fail-open. Fail closed policy is evaluated as "failing"
          if !target_branch_pipeline && fail_open?(approval_rule)
            evaluation.error!(approval_rule, :target_pipeline_missing, context: validation_context)
            next
          end

          rule_violated, violation_data = rule_violated?(approval_rule)

          if rule_violated
            evaluation.fail!(approval_rule, data: violation_data, context: validation_context)
            log_update_approval_rule('Updating MR approval rule', reason: 'license_finding rule violated',
              approval_rule_id: approval_rule.id, approval_rule_name: approval_rule.name)
          else
            evaluation.pass!(approval_rule)
          end
        end
      end

      def rule_violated?(rule)
        denied_licenses_with_dependencies = denied_licenses_with_dependency(rule)

        if denied_licenses_with_dependencies.present?
          return true, build_violation_data(denied_licenses_with_dependencies)
        end

        [false, nil]
      end

      def denied_licenses_with_dependency(rule)
        if licenses_with_package_exclusions?(rule)
          Security::MergeRequestApprovalPolicies::DeniedLicensesChecker.new(
            project, report, target_branch_report, rule.scan_result_policy_read,
            rule.approval_policy_rule).denied_licenses_with_dependencies
        else
          violation_checker.execute(rule.scan_result_policy_read)
        end
      end

      def licenses_with_package_exclusions?(rule)
        rule.scan_result_policy_read.licenses.present? || rule&.approval_policy_rule&.licenses.present?
      end

      def violation_checker
        Security::ScanResultPolicies::LicenseViolationChecker.new(project, report, target_branch_report)
      end

      def scanner
        ::Gitlab::LicenseScanning.scanner_for_pipeline(project, source_pipeline)
      end
      strong_memoize_attr :scanner

      def report
        scanner.report
      end

      def target_branch_report
        ::Gitlab::LicenseScanning.scanner_for_pipeline(project, target_branch_pipeline).report
      end

      def evaluation
        @evaluation ||= Security::SecurityOrchestrationPolicies::PolicyRuleEvaluationService.new(merge_request)
      end

      def source_pipeline
        return pipeline if pipeline.nil? || pipeline.has_sbom_reports?

        # We use dependency_scanning_reports instead of SBOM reports because
        # container scanning job also generates SBOM reports. We might pick a pipeline with CS job and not DS job.
        # TODO: Investigate use of SBOM reports in https://gitlab.com/gitlab-org/gitlab/-/issues/500106
        pipeline_with_dependency_scanning_reports(related_pipelines(pipeline)) || pipeline
      end
      strong_memoize_attr :source_pipeline

      def target_branch_pipeline
        target_pipeline = merge_request.latest_comparison_pipeline_with_sbom_reports

        return target_pipeline if target_pipeline.present?

        related_target_pipeline
      end
      strong_memoize_attr :target_branch_pipeline

      def related_target_pipeline
        target_pipeline_without_report = merge_request.merge_base_pipeline || merge_request.base_pipeline

        return unless target_pipeline_without_report

        related_pipeline_ids = Security::RelatedPipelinesFinder.new(target_pipeline_without_report, {
          sources: Enums::Ci::Pipeline.ci_and_security_orchestration_sources.values,
          ref: merge_request.target_branch
        }).execute

        pipeline_with_dependency_scanning_reports(project.all_pipelines.id_in(related_pipeline_ids))
      end

      def pipeline_with_dependency_scanning_reports(pipelines)
        pipelines.find { |pipeline| pipeline.self_and_project_descendants.any?(&:has_dependency_scanning_reports?) }
      end

      def validation_context
        { pipeline_ids: [source_pipeline&.id].compact, target_pipeline_ids: [target_branch_pipeline&.id].compact }
      end

      def log_update_approval_rule(message, **attributes)
        log_policy_evaluation('update_approvals', message,
          project: project, merge_request_id: merge_request.id,
          merge_request_iid: merge_request.iid, **attributes.merge(validation_context))
      end

      def build_violation_data(denied_licenses_with_dependencies)
        return if denied_licenses_with_dependencies.blank?

        denied_licenses_with_dependencies.first(Security::ScanResultPolicyViolation::MAX_VIOLATIONS)
                                         .to_h
                                         .transform_values do |dependencies|
          Security::ScanResultPolicyViolation.trim_violations(dependencies)
        end
      end

      def fail_open?(approval_rule)
        approval_rule.scan_result_policy_read&.fail_open?
      end
    end
  end
end
