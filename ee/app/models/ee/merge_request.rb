# frozen_string_literal: true

module EE
  module MergeRequest
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    include ::Gitlab::Allowable
    include ::Gitlab::Utils::StrongMemoize
    include FromUnion

    MAX_CHECKED_PIPELINES_FOR_SECURITY_REPORT_COMPARISON = 10

    prepended do
      include Elastic::ApplicationVersionedSearch
      include DeprecatedApprovalsBeforeMerge
      include UsageStatistics
      include IterationEventable

      belongs_to :iteration, foreign_key: 'sprint_id', inverse_of: :merge_requests

      has_many :approvers, as: :target, dependent: :delete_all # rubocop:disable Cop/ActiveRecordDependent -- legacy usage
      has_many :approver_users, through: :approvers, source: :user
      has_many :approver_groups, as: :target, dependent: :delete_all # rubocop:disable Cop/ActiveRecordDependent -- legacy usage
      has_many :status_check_responses, class_name: 'MergeRequests::StatusCheckResponse', inverse_of: :merge_request
      has_many :approval_rules, class_name: 'ApprovalMergeRequestRule', inverse_of: :merge_request do
        def applicable_to_branch(branch)
          ActiveRecord::Associations::Preloader.new(
            records: self,
            associations: [:users, :groups, { approval_project_rule: [:users, :groups, :protected_branches] }]
          ).call

          self.select { |rule| rule.applicable_to_branch?(branch) }
        end

        def set_applicable_when_copying_rules(applicable_ids)
          where.not(id: applicable_ids).update_all(applicable_post_merge: false)
          where(id: applicable_ids).update_all(applicable_post_merge: true)
        end
      end
      has_many :applicable_post_merge_approval_rules,
        -> { applicable_post_merge },
        class_name: 'ApprovalMergeRequestRule',
        inverse_of: :merge_request
      has_many :approval_merge_request_rule_sources, through: :approval_rules
      has_many :approval_project_rules, through: :approval_merge_request_rule_sources
      # rubocop:disable Cop/ActiveRecordDependent -- legacy usage
      has_one :merge_train_car, class_name: 'MergeTrains::Car', inverse_of: :merge_request, dependent: :destroy
      # rubocop:enable Cop/ActiveRecordDependent -- legacy usage

      has_many :blocks_as_blocker,
        class_name: 'MergeRequestBlock',
        inverse_of: :blocking_merge_request,
        foreign_key: :blocking_merge_request_id

      has_many :blocks_as_blockee,
        class_name: 'MergeRequestBlock',
        inverse_of: :blocked_merge_request,
        foreign_key: :blocked_merge_request_id

      has_many :blocking_merge_requests, through: :blocks_as_blockee

      has_many :blocked_merge_requests, through: :blocks_as_blocker

      has_many :compliance_violations, class_name: 'MergeRequests::ComplianceViolation'
      has_many :scan_result_policy_violations, class_name: 'Security::ScanResultPolicyViolation'

      has_many :requested_changes,
        class_name: 'MergeRequests::RequestedChange',
        inverse_of: :merge_request
      has_many :change_requesters,
        class_name: 'User',
        through: :requested_changes,
        source: :user

      has_many :scan_result_policy_reads_through_violations,
        through: :scan_result_policy_violations, source: :scan_result_policy_read,
        class_name: 'Security::ScanResultPolicyRead'

      has_many :security_policies_through_violations,
        through: :scan_result_policy_violations, source: :security_policy,
        class_name: 'Security::Policy'

      has_many :scan_result_policy_reads_through_approval_rules,
        through: :approval_rules, source: :scan_result_policy_read,
        class_name: 'Security::ScanResultPolicyRead'

      has_many :running_scan_result_policy_violations, -> { running }, class_name:
        'Security::ScanResultPolicyViolation', inverse_of: :merge_request

      has_many :failed_scan_result_policy_violations, -> { failed }, class_name:
        'Security::ScanResultPolicyViolation', inverse_of: :merge_request

      has_many :merge_request_stage_events, class_name: 'Analytics::CycleAnalytics::MergeRequestStageEvent'

      # WIP v2 approval rules as part of https://gitlab.com/groups/gitlab-org/-/epics/12955
      has_many :v2_approval_rules_merge_requests, class_name: 'MergeRequests::ApprovalRulesMergeRequest',
        inverse_of: :merge_request
      has_many :v2_approval_rules, through: :v2_approval_rules_merge_requests,
        class_name: 'MergeRequests::ApprovalRule', source: :approval_rule

      delegate :sha, to: :head_pipeline, prefix: :head_pipeline, allow_nil: true
      delegate :sha, to: :base_pipeline, prefix: :base_pipeline, allow_nil: true
      delegate :wrapped_approval_rules, :invalid_approvers_rules, to: :approval_state

      accepts_nested_attributes_for :approval_rules, allow_destroy: true
      accepts_nested_attributes_for :v2_approval_rules, allow_destroy: true

      scope :not_merged, -> { where.not(merge_requests: { state_id: ::MergeRequest.available_states[:merged] }) }

      scope :order_review_time_desc, -> do
        joins(:metrics).reorder(::MergeRequest::Metrics.review_time_field.asc.nulls_last)
      end

      scope :with_code_review_api_entity_associations, -> do
        preload(
          :author, :approved_by_users, :metrics,
          latest_merge_request_diff: :merge_request_diff_files, target_project: :namespace, milestone: :project)
      end

      scope :including_merge_train, -> do
        includes(:merge_train_car)
      end

      scope :with_head_pipeline, -> { where.not(head_pipeline_id: nil) }

      scope :for_projects_with_security_policy_project, -> do
        joins('INNER JOIN security_orchestration_policy_configurations ' \
              'ON merge_requests.target_project_id = security_orchestration_policy_configurations.project_id')
      end

      scope :with_applied_scan_result_policies, -> do
        joins(:approval_rules).merge(ApprovalMergeRequestRule.from_scan_result_policy)
      end

      after_create_commit :create_pending_status_check_responses, if: :allow_external_status_checks?
      after_update :sync_merge_request_compliance_violation, if: :saved_change_to_title?

      def sync_merge_request_compliance_violation
        compliance_violations.update_all(title: title)
      end

      def create_pending_status_check_responses
        return unless diff_head_sha.present?

        ::ComplianceManagement::PendingStatusCheckWorker.perform_async(id, project.id, diff_head_sha)
      end

      def merge_requests_author_approval?
        !!target_project&.merge_requests_author_approval? &&
          !policy_approval_settings.fetch(:prevent_approval_by_author, false)
      end

      def merge_requests_disable_committers_approval?
        !!target_project&.merge_requests_disable_committers_approval? ||
          policy_approval_settings.fetch(:prevent_approval_by_commit_author, false)
      end

      def require_password_to_approve?
        target_project&.require_password_to_approve? ||
          policy_approval_settings.fetch(:require_password_to_approve, false)
      end

      def policy_approval_settings
        return {} if scan_result_policy_violations.empty?

        scan_result_policy_reads_through_violations
          .reduce({}) do |acc, read|
            acc.merge!(read.project_approval_settings.select { |_, value| value }.symbolize_keys)
          end
      end
      strong_memoize_attr :policy_approval_settings

      def policies_overriding_approval_settings
        return {} if scan_result_policy_violations.empty?

        if security_policies_through_violations.any?
          security_policies_through_violations
            .select { |policy| policy.content['approval_settings']&.compact_blank.present? }
            .index_with { |policy| policy.content['approval_settings'].compact_blank.symbolize_keys }
        else
          # TODO: Temporary code path without policy details
          # Remove when backfill from https://gitlab.com/gitlab-org/gitlab/-/merge_requests/173714 is finished
          scan_result_policy_reads_through_violations
            .select { |read| read.project_approval_settings.compact_blank.present? }
            .to_h do |read|
              policy = Security::Policy.new(
                security_orchestration_policy_configuration_id: read.security_orchestration_policy_configuration_id,
                policy_index: read.orchestration_policy_idx)
              settings = read.project_approval_settings.compact_blank.symbolize_keys

              [policy, settings]
            end
        end
      end
      strong_memoize_attr :policies_overriding_approval_settings

      # It allows us to finalize the approval rules of merged merge requests
      attr_accessor :finalizing_rules

      # Used to show warning messages when Duo Code Review is attempted without a seat
      attr_accessor :duo_code_review_attempted
    end

    class_methods do
      extend ::Gitlab::Utils::Override

      # This is an ActiveRecord scope in CE
      def with_web_entity_associations
        super.preload(target_project: :invited_groups)
      end

      # This is an ActiveRecord scope in CE
      def with_api_entity_associations
        super.preload(
          :blocking_merge_requests, :scan_result_policy_reads_through_violations,
          :scan_result_policy_reads_through_approval_rules,
          :running_scan_result_policy_violations, :requested_changes,
          :approvals, :approved_by_users, :scan_result_policy_violations,
          applicable_post_merge_approval_rules: [
            :approved_approvers, :group_users, :users, :approval_policy_rule,
            { approval_project_rule: [:protected_branches, :group_users, :users] }
          ],
          approval_rules: [
            :group_users, :users,
            { approval_project_rule: [:group_users, :users] }
          ],
          target_project: [
            :regular_or_any_approver_approval_rules,
            {
              regular_or_any_approver_approval_rules: [
                :group_users, :users
              ]
            },
            :protected_branches,
            { protected_branches: [:squash_option] },
            { group: :saml_provider }
          ]
        )
      end

      def sort_by_attribute(method, *args, **kwargs)
        if method.to_s == 'review_time_desc'
          order_review_time_desc
        else
          super
        end
      end

      # Includes table keys in group by clause when sorting
      # preventing errors in postgres
      #
      # Returns an array of arel columns
      def grouping_columns(sort)
        grouping_columns = super
        grouping_columns << ::MergeRequest::Metrics.review_time_field if sort.to_s == 'review_time_desc'
        grouping_columns
      end

      # override
      def use_separate_indices?
        true
      end

      override :mergeable_state_checks
      def mergeable_state_checks
        [
          ::MergeRequests::Mergeability::CheckRequestedChangesService,
          ::MergeRequests::Mergeability::CheckApprovedService,
          ::MergeRequests::Mergeability::CheckBlockedByOtherMrsService,
          ::MergeRequests::Mergeability::CheckJiraStatusService,
          ::MergeRequests::Mergeability::CheckSecurityPolicyViolationsService,
          ::MergeRequests::Mergeability::CheckExternalStatusChecksPassedService,
          ::MergeRequests::Mergeability::CheckPathLocksService
        ] + super
      end
    end

    override :predefined_variables
    def predefined_variables
      super.concat(merge_request_approval_variables)
    end

    override :merge_blocked_by_other_mrs?
    def merge_blocked_by_other_mrs?
      strong_memoize(:merge_blocked_by_other_mrs) do
        blocking_merge_requests_feature_available? &&
          blocking_merge_requests.any? { |mr| !mr.merged? }
      end
    end

    def on_train?
      merge_train_car&.active?
    end

    def allow_external_status_checks?
      project.licensed_feature_available?(:external_status_checks)
    end

    def visible_blocking_merge_requests(user)
      Ability.merge_requests_readable_by_user(blocking_merge_requests, user)
    end

    def visible_blocking_merge_request_refs(user)
      visible_blocking_merge_requests(user).map do |mr|
        mr.to_reference(target_project)
      end
    end

    # Unlike +visible_blocking_merge_requests+, this method doesn't include
    # blocking MRs that have been merged. This simplifies output, since we don't
    # need to tell the user that there are X hidden blocking MRs, of which only
    # Y are an obstacle. Pass include_merged: true to override this behaviour.
    def hidden_blocking_merge_requests_count(user, include_merged: false)
      hidden = blocking_merge_requests - visible_blocking_merge_requests(user)

      hidden.delete_if(&:merged?) unless include_merged

      hidden.count
    end

    def has_denied_policies?
      return false unless license_scanning_feature_available?

      return false unless diff_head_pipeline

      return false unless ::Gitlab::LicenseScanning
        .scanner_for_pipeline(project, diff_head_pipeline)
        .results_available?

      return false if has_approved_license_check?

      report_diff = compare_reports(::Ci::CompareLicenseScanningReportsService)

      licenses = report_diff.dig(:data, 'new_licenses')

      return false if licenses.nil? || licenses.empty?

      licenses.any? do |l|
        status = l.dig('classification', 'approval_status')
        'denied' == status
      end
    end

    def enabled_reports
      {
        sast: report_type_enabled?(:sast),
        container_scanning: report_type_enabled?(:container_scanning),
        dast: report_type_enabled?(:dast),
        dependency_scanning: report_type_enabled?(:dependency_scanning) || report_type_enabled?(:cyclonedx),
        license_scanning: report_type_enabled?(:license_scanning),
        coverage_fuzzing: report_type_enabled?(:coverage_fuzzing),
        secret_detection: report_type_enabled?(:secret_detection),
        api_fuzzing: report_type_enabled?(:api_fuzzing)
      }
    end

    def has_security_reports?
      !!diff_head_pipeline&.complete_or_manual_and_has_reports?(::Ci::JobArtifact.security_reports)
    end

    def has_dependency_scanning_reports?
      !!diff_head_pipeline&.complete_or_manual_and_has_reports?(::Ci::JobArtifact.with_file_types(%w[
        dependency_scanning cyclonedx
      ]))
    end

    def compare_dependency_scanning_reports(current_user)
      return missing_report_error("dependency scanning") unless has_dependency_scanning_reports?

      compare_reports(::Ci::CompareSecurityReportsService, current_user, 'dependency_scanning')
    end

    def has_container_scanning_reports?
      if ::Feature.enabled?(:show_child_reports_in_mr_page, project)
        !!diff_head_pipeline&.complete_or_manual? && pipeline_has_report_in_self_or_descendants?(:container_scanning)
      else
        !!diff_head_pipeline&.complete_or_manual_and_has_reports?(::Ci::JobArtifact.of_report_type(:container_scanning))
      end
    end

    def compare_container_scanning_reports(current_user)
      return missing_report_error("container scanning") unless has_container_scanning_reports?

      compare_reports(::Ci::CompareSecurityReportsService, current_user, 'container_scanning')
    end

    def has_dast_reports?
      !!diff_head_pipeline&.complete_or_manual_and_has_reports?(::Ci::JobArtifact.of_report_type(:dast))
    end

    def compare_dast_reports(current_user)
      return missing_report_error("DAST") unless has_dast_reports?

      compare_reports(::Ci::CompareSecurityReportsService, current_user, 'dast')
    end

    def compare_license_scanning_reports(current_user)
      unless ::Gitlab::LicenseScanning.scanner_for_pipeline(project, diff_head_pipeline).results_available?
        return missing_report_error("license scanning")
      end

      compare_reports(::Ci::CompareLicenseScanningReportsService, current_user)
    end

    def compare_license_scanning_reports_collapsed(current_user)
      unless ::Gitlab::LicenseScanning.scanner_for_pipeline(project, diff_head_pipeline).results_available?
        return missing_report_error("license scanning")
      end

      compare_reports(
        ::Ci::CompareLicenseScanningReportsCollapsedService,
        current_user,
        'license_scanning',
        additional_params: { license_check: approval_rules.license_compliance.any? }
      )
    end

    def has_metrics_reports?
      if ::Feature.enabled?(:show_child_reports_in_mr_page, project)
        !!diff_head_pipeline&.complete_and_has_self_or_descendant_reports?(::Ci::JobArtifact.of_report_type(:metrics))
      else
        !!diff_head_pipeline&.complete_and_has_reports?(::Ci::JobArtifact.of_report_type(:metrics))
      end
    end

    def compare_metrics_reports
      return missing_report_error("metrics") unless has_metrics_reports?

      compare_reports(::Ci::CompareMetricsReportsService)
    end

    def has_coverage_fuzzing_reports?
      !!diff_head_pipeline&.complete_or_manual_and_has_reports?(::Ci::JobArtifact.of_report_type(:coverage_fuzzing))
    end

    def compare_coverage_fuzzing_reports(current_user)
      return missing_report_error("coverage fuzzing") unless has_coverage_fuzzing_reports?

      compare_reports(::Ci::CompareSecurityReportsService, current_user, 'coverage_fuzzing')
    end

    def has_api_fuzzing_reports?
      !!diff_head_pipeline&.complete_or_manual_and_has_reports?(::Ci::JobArtifact.of_report_type(:api_fuzzing))
    end

    def compare_api_fuzzing_reports(current_user)
      return missing_report_error('api fuzzing') unless has_api_fuzzing_reports?

      compare_reports(::Ci::CompareSecurityReportsService, current_user, 'api_fuzzing')
    end

    def synchronize_approval_rules_from_target_project
      return if merged?

      project_rules = target_project.approval_rules.report_approver.includes(:users, :groups)

      project_rules.find_each do |project_rule|
        project_rule.apply_report_approver_rules_to(self) do |rule_attributes|
          rule_attributes[:approvals_required] = 0 if project_rule.from_scan_result_policy?
        end
      end
    end

    def schedule_policy_synchronization
      if project.scan_result_policy_reads.targeting_commits.any?
        # We need to make sure to run the merge request worker after hooks were called to
        # get correct commit signatures
        ::Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker.perform_async(id)
      end

      if approval_rules.by_report_types([:scan_finding, :license_scanning]).any?
        ::Security::ScanResultPolicies::SyncPreexistingStatesApprovalRulesWorker.perform_async(id)
      end

      if head_pipeline_id
        ::Ci::SyncReportsToReportApprovalRulesWorker.perform_async(head_pipeline_id)

        # This is needed here to avoid inconsistent state when the scan result policy is updated after the
        # head pipeline completes and before the merge request is created, we might have inconsistent state.
        ::Security::ScanResultPolicies::SyncMergeRequestApprovalsWorker.perform_async(head_pipeline_id, id)
        ::Security::UnenforceablePolicyRulesPipelineNotificationWorker.perform_async(head_pipeline_id)
      else
        ::Security::UnenforceablePolicyRulesNotificationWorker.perform_async(id)
      end
    end

    def security_policies_with_branch_exceptions
      approval_rules
        .includes(approval_policy_rule: :security_policy)
        .select(&:branches_exempted_by_policy?)
        .map(&:approval_policy_rule)
        .map(&:security_policy)
        .uniq
    end
    strong_memoize_attr :security_policies_with_branch_exceptions

    # TODO: Will be removed with https://gitlab.com/gitlab-org/gitlab/-/issues/504296
    def sync_project_approval_rules_for_policy_configuration(configuration_id)
      return if merged?

      project_rules = target_project
        .approval_rules
        .report_approver
        .for_policy_configuration(configuration_id)
        .includes(:users, :groups)

      project_rules.find_each do |project_rule|
        project_rule.apply_report_approver_rules_to(self)
      end
    end

    def sync_project_approval_rules_for_approval_policy_rules(policy_rules)
      return if merged?

      project_rules = target_project
        .approval_rules
        .report_approver
        .for_approval_policy_rules(policy_rules)
        .includes(:users, :groups)

      project_rules.find_each do |project_rule|
        project_rule.apply_report_approver_rules_to(self)
      end
    end

    def delete_approval_rules_for_policy_configuration(configuration_id)
      return if merged?

      approval_rules.for_policy_configuration(configuration_id).delete_all
    end

    def finalize_rules
      self.finalizing_rules = true
      yield
      self.finalizing_rules = false
    end

    def reset_required_approvals(approval_rules)
      return if merged?

      approval_rules.filter_map(&:source_rule).map do |rule|
        rule.apply_report_approver_rules_to(self)
      end
    end

    def applicable_approval_rules_for_user(user_id)
      wrapped_approval_rules.select do |rule|
        rule.approvers.pluck(:id).include?(user_id)
      end
    end

    def security_reports_up_to_date?
      project.security_reports_up_to_date_for_ref?(target_branch)
    end

    def audit_details
      title
    end

    def latest_pipeline_for_target_branch
      @latest_pipeline ||= project.ci_pipelines
          .order(id: :desc)
          .find_by(ref: target_branch)
    end

    def latest_comparison_pipeline_with_sbom_reports
      target_shas = [diff_head_pipeline&.target_sha, diff_base_sha, diff_start_sha]
      find_target_branch_pipeline_by_sha_in_order_of_preference(target_shas, :has_sbom_reports?)
    end

    def latest_scan_finding_comparison_pipeline
      target_shas = [diff_head_pipeline&.target_sha, diff_base_sha, diff_start_sha]
      find_target_branch_pipeline_by_sha_in_order_of_preference(target_shas, :has_security_reports?)
    end

    def diff_head_pipeline?(pipeline)
      pipeline.source_sha == diff_head_sha || pipeline.sha == diff_head_sha
    end

    override :can_suggest_reviewers?
    def can_suggest_reviewers?
      open? && modified_paths.any?
    end

    override :suggested_reviewer_users
    def suggested_reviewer_users
      return ::User.none unless predictions && predictions.suggested_reviewers.is_a?(Hash)

      usernames = Array.wrap(suggested_reviewers["reviewers"])
      return ::User.none if usernames.empty?

      # Preserve the original order of suggested usernames
      join_sql = ::MergeRequest.sanitize_sql_array(
        [
          'JOIN UNNEST(ARRAY[?]::varchar[]) WITH ORDINALITY AS t(username, ord) USING(username)',
          usernames
        ]
      )

      project.authorized_users.with_state(:active).human
        .joins(Arel.sql(join_sql))
        .order('t.ord')
    end

    def rebase_commit_is_different?(newrev)
      rebase_commit_sha != newrev
    end

    def merge_train
      target_project.merge_train_for(target_branch)
    end

    override :should_be_rebased?
    def should_be_rebased?
      return false if MergeTrains::Train.project_using_ff?(target_project)
      return false if merge_train_car&.on_ff_train?

      super
    end

    override :comparison_base_pipeline
    def comparison_base_pipeline(service_class)
      return super unless security_comparison?(service_class)

      latest_scan_finding_comparison_pipeline
    end

    def blocking_merge_requests_feature_available?
      project.licensed_feature_available?(:blocking_merge_requests)
    end

    def license_scanning_feature_available?
      project.licensed_feature_available?(:license_scanning)
    end

    def notify_approvers
      approvers = wrapped_approval_rules.flat_map(&:approvers).uniq

      ::NotificationService.new.added_as_approver(approvers, self)
    end

    def reviewer_requests_changes_feature
      project.feature_available?(:requested_changes_block_merge_request)
    end

    def has_changes_requested?
      requested_changes.any?
    end

    override :create_requested_changes
    def create_requested_changes(user)
      requested_changes.find_or_create_by(project_id: project_id, user_id: user.id)
    end

    override :destroy_requested_changes
    def destroy_requested_changes(user)
      requested_changes.where(user_id: user.id).delete_all
    end

    def requested_changes_for_users(user_ids)
      requested_changes.where(user_id: user_ids)
    end

    def ai_review_merge_request_allowed?(user)
      project.ai_review_merge_request_allowed?(user) && Ability.allowed?(user, :create_note, self)
    end

    def ai_reviewable_diff_files
      diffs.diff_files.select(&:ai_reviewable?)
    end

    def temporarily_unapproved?
      approval_state.temporarily_unapproved?
    end

    override :squash_option
    def squash_option
      protected_branch = target_project.protected_branches.then do |protected_branches|
        if protected_branches.loaded?
          protected_branches.find { |protected_branch| protected_branch.name == target_branch }
        else
          protected_branches.find_by(name: target_branch)
        end
      end

      return protected_branch.squash_option if protected_branch&.squash_option

      super
    end
    strong_memoize_attr :squash_option

    def policy_bot_comment
      notes
        .authored_by(::Users::Internal.security_bot)
        .note_starting_with(Security::ScanResultPolicies::PolicyViolationComment::MESSAGE_HEADER).first
    end

    def approval_rules_editable_by?(user)
      return unless user

      user.can_admin_all_resources? ||
        (project.can_override_approvers? &&
         (assigned_or_authored_by_with_access?(user) ||
          project.team.member?(user, ::Gitlab::Access::MAINTAINER)))
    end

    private

    def assigned_or_authored_by_with_access?(user)
      assignee_or_author?(user) &&
        (project.member?(user) ||
         project.project_feature.merge_requests_access_level == ::Featurable::PUBLIC)
    end

    def security_comparison?(service_class)
      service_class == ::Ci::CompareSecurityReportsService
    end

    def find_target_branch_pipeline_by_sha_in_order_of_preference(shas, predicate)
      pipelines = shas
        .compact
        .lazy
        .flat_map do |sha|
          target_branch_pipelines_for(sha: sha)
            .order(id: :desc)
            .limit(MAX_CHECKED_PIPELINES_FOR_SECURITY_REPORT_COMPARISON)
        end

      pipelines.find { |pipeline| pipeline.self_and_project_descendants.any?(&predicate) }
    end

    def has_approved_license_check?
      if rule = approval_rules.license_compliance.last
        ApprovalWrappedRule.wrap(self, rule).approved?
      end
    end

    def merge_request_approval_variables
      return unless approval_feature_available?

      strong_memoize(:merge_request_approval_variables) do
        ::Gitlab::Ci::Variables::Collection.new.tap do |variables|
          variables.append(key: 'CI_MERGE_REQUEST_APPROVED', value: approved?.to_s) if approved?
        end
      end
    end
  end
end
