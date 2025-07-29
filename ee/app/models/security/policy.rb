# frozen_string_literal: true

module Security
  class Policy < ApplicationRecord
    include EachBatch
    include Security::Policies::VulnerabilityManagement
    include Gitlab::Utils::StrongMemoize

    self.table_name = 'security_policies'
    self.inheritance_column = :_type_disabled

    POLICY_CONTENT_FIELDS = {
      approval_policy: %i[actions approval_settings fallback_behavior policy_tuning bypass_settings],
      scan_execution_policy: %i[actions skip_ci],
      pipeline_execution_policy: %i[content pipeline_config_strategy suffix skip_ci variables_override],
      vulnerability_management_policy: %i[actions],
      pipeline_execution_schedule_policy: %i[content schedules]
    }.freeze
    APPROVAL_MERGE_REQUEST_RULES_BATCH_SIZE = 5000

    belongs_to :security_orchestration_policy_configuration, class_name: 'Security::OrchestrationPolicyConfiguration'
    belongs_to :security_policy_management_project, class_name: 'Project'
    has_many :approval_policy_rules, class_name: 'Security::ApprovalPolicyRule', foreign_key: 'security_policy_id',
      inverse_of: :security_policy
    has_many :scan_execution_policy_rules, class_name: 'Security::ScanExecutionPolicyRule',
      foreign_key: 'security_policy_id', inverse_of: :security_policy
    has_many :vulnerability_management_policy_rules, class_name: 'Security::VulnerabilityManagementPolicyRule',
      foreign_key: 'security_policy_id', inverse_of: :security_policy
    has_many :security_policy_project_links, class_name: 'Security::PolicyProjectLink',
      foreign_key: :security_policy_id, inverse_of: :security_policy
    has_one :security_pipeline_execution_policy_config_link,
      class_name: 'Security::PipelineExecutionPolicyConfigLink',
      foreign_key: :security_policy_id, inverse_of: :security_policy

    has_many :projects, through: :security_policy_project_links

    has_many :security_pipeline_execution_project_schedules, class_name: 'Security::PipelineExecutionProjectSchedule',
      foreign_key: :security_policy_id, inverse_of: :security_policy

    enum :type, {
      approval_policy: 0,
      scan_execution_policy: 1,
      pipeline_execution_policy: 2,
      vulnerability_management_policy: 3,
      pipeline_execution_schedule_policy: 4
    }, prefix: true

    validates :security_orchestration_policy_configuration_id,
      uniqueness: { scope: %i[type policy_index] }

    validates :scope, json_schema: { filename: "security_policy_scope" }
    validates :scope, exclusion: { in: [nil] }

    validates :content, json_schema: { filename: "approval_policy_content" }, if: :type_approval_policy?
    validates :content, json_schema: { filename: "pipeline_execution_policy_content" },
      if: :type_pipeline_execution_policy?
    validates :content, json_schema: { filename: "pipeline_execution_schedule_policy_content" },
      if: :type_pipeline_execution_schedule_policy?
    validates :content, json_schema: { filename: "scan_execution_policy_content" }, if: :type_scan_execution_policy?
    validates :content, json_schema: { filename: "vulnerability_management_policy_content" },
      if: :type_vulnerability_management_policy?

    validates :content, exclusion: { in: [nil] }
    validates :description, length: { maximum: Gitlab::Database::MAX_TEXT_SIZE_LIMIT }

    scope :undeleted, -> { where('policy_index >= 0') }
    scope :order_by_index, -> { order(policy_index: :asc) }
    scope :enabled, -> { where(enabled: true) }
    scope :for_policy_configuration, ->(policy_configuration) {
      where(security_orchestration_policy_configuration: policy_configuration)
    }

    scope :for_custom_role, ->(custom_role_id) do
      where("content->'actions' @> ?", [{ role_approvers: [custom_role_id] }].to_json)
    end

    scope :with_bypass_settings, -> do
      where("content->'bypass_settings' IS NOT NULL").where("content->'bypass_settings' <> ?", '{}')
    end

    delegate :namespace?, :namespace, :project?, :project, to: :security_orchestration_policy_configuration

    def self.checksum(policy_hash)
      Digest::SHA256.hexdigest(policy_hash.to_json)
    end

    def self.attributes_from_policy_hash(policy_type, policy_hash, policy_configuration)
      # NOTE: We don't include `metadata` here because it contains internal information.
      {
        type: policy_type,
        name: policy_hash[:name],
        description: policy_hash[:description],
        enabled: policy_hash[:enabled],
        scope: policy_hash.fetch(:policy_scope, {}),
        content: policy_hash.slice(*POLICY_CONTENT_FIELDS[policy_type]),
        checksum: checksum(policy_hash),
        security_policy_management_project_id: policy_configuration.security_policy_management_project_id
      }.compact
    end

    def self.rule_attributes_from_rule_hash(policy_type, rule_hash, policy_configuration)
      Security::PolicyRule.for_policy_type(policy_type).attributes_from_rule_hash(rule_hash, policy_configuration)
    end

    def self.upsert_policy(policy_type, policies, policy_hash, policy_index, policy_configuration)
      policy = policies.find_or_initialize_by(policy_index: policy_index, type: policy_type)
      policy.update!(attributes_from_policy_hash(policy_type, policy_hash, policy_configuration))

      if policy.supports_policy_rules?
        Array.wrap(policy_hash[:rules]).map.with_index do |rule_hash, rule_index|
          policy.upsert_rule(rule_index, rule_hash)
        end
      end

      policy.update_pipeline_execution_policy_config_link!
      policy
    end

    def self.delete_by_ids(ids)
      id_in(ids).delete_all
    end

    def self.next_deletion_index
      (maximum("ABS(policy_index)") || 0) + 1
    end

    def link_project!(project)
      transaction do
        security_policy_project_links.for_project(project).first_or_create!
        link_policy_rules_project!(project)

        if type_pipeline_execution_schedule_policy? && Feature.enabled?(:scheduled_pipeline_execution_policies, project)
          # Newly introduced columns will be written by https://gitlab.com/gitlab-org/gitlab/-/merge_requests/180714
          # security_pipeline_execution_project_schedules.for_project(project).first_or_create!
        end
      end
    end

    def unlink_project!(project)
      transaction do
        security_policy_project_links.for_project(project).delete_all
        security_pipeline_execution_project_schedules.for_project(project).delete_all
        unlink_policy_rules_project!(project)
      end
    end

    def update_project_approval_policy_rule_links(project, created_rules, deleted_rules)
      transaction do
        unlink_policy_rules_project!(project, deleted_rules)
        link_policy_rules_project!(project, created_rules)
      end
    end

    def update_pipeline_execution_policy_config_link!
      return unless type_pipeline_execution_policy?

      security_pipeline_execution_policy_config_link&.destroy!

      config_project = Project.find_by_full_path(pipeline_execution_ci_config['project'])
      create_security_pipeline_execution_policy_config_link!(project: config_project) if config_project
    end

    def upsert_rule(rule_index, rule_hash)
      rule = Security::PolicyRule
        .for_policy_type(type.to_sym)
        .find_or_initialize_by(security_policy_id: id, rule_index: rule_index)

      rule.update!(
        self.class.rule_attributes_from_rule_hash(type.to_sym, rule_hash, security_orchestration_policy_configuration)
      )

      rule
    end

    def to_policy_hash
      {
        name: name,
        description: description,
        enabled: enabled,
        policy_scope: scope.deep_symbolize_keys,
        metadata: metadata
      }.merge(content_by_type)
    end

    def all_rules
      if type_approval_policy?
        approval_policy_rules
      elsif type_scan_execution_policy?
        scan_execution_policy_rules
      elsif type_vulnerability_management_policy?
        vulnerability_management_policy_rules
      end
    end

    def rules
      Array.wrap(all_rules&.undeleted)
    end

    def max_rule_index
      all_rules&.maximum("ABS(rule_index)") || 0
    end

    def next_rule_index
      rules.empty? ? 0 : (rules.maximum(:rule_index) + 1)
    end

    def scope_applicable?(project)
      strong_memoize_with(:scope_applicable, project) do
        policy_scope_checker = Security::SecurityOrchestrationPolicies::PolicyScopeChecker.new(project: project)
        policy_scope_checker.security_policy_applicable?(self)
      end
    end

    def scope_has_framework?(compliance_framework_id)
      scope
        .deep_symbolize_keys[:compliance_frameworks].to_a
        .any? { |framework| framework[:id] == compliance_framework_id }
    end

    def framework_ids_from_scope
      # rubocop:disable Database/AvoidUsingPluckWithoutLimit -- pluck is used for hash
      Array.wrap(scope.deep_symbolize_keys[:compliance_frameworks]).pluck(:id).uniq
      # rubocop:enable Database/AvoidUsingPluckWithoutLimit
    end

    def delete_approval_policy_rules
      delete_approval_rules
      delete_policy_violations
      delete_software_license_policies

      approval_policy_rules.delete_all(:delete_all)
    end

    def delete_approval_policy_rules_for_project(project, rules)
      policy_configuration = security_orchestration_policy_configuration

      policy_configuration.approval_project_rules.where(project_id: project.id).each_batch do |batch|
        batch.for_approval_policy_rules(rules).delete_all
      end

      policy_configuration
        .approval_merge_request_rules
        .each_batch(of: APPROVAL_MERGE_REQUEST_RULES_BATCH_SIZE) do |batch|
          batch
            .for_unmerged_merge_requests
            .for_merge_request_project(project.id)
            .for_approval_policy_rules(rules)
            .delete_all
        end

      project.scan_result_policy_violations.each_batch do |batch|
        batch.where(approval_policy_rules: rules).delete_all
      end

      delete_software_license_policies_for_project(project, rules)
      delete_scan_result_policy_reads_for_project(project, rules)
    end

    def delete_software_license_policies_for_project(project, rules)
      project.software_license_policies.each_batch do |batch|
        batch.where(approval_policy_rules: rules).delete_all
      end
    end

    # TODO: Will be removed with https://gitlab.com/gitlab-org/gitlab/-/issues/504296
    def delete_scan_result_policy_reads_for_project(project, rules)
      project.scan_result_policy_reads.for_approval_policy_rules(rules).delete_all
    end

    def delete_scan_execution_policy_rules
      scan_execution_policy_rules.delete_all(:delete_all)
    end

    def delete_security_pipeline_execution_project_schedules
      security_pipeline_execution_project_schedules.each_batch do |batch|
        batch.delete_all
      end
    end

    def edit_path
      return if name.blank?

      id = CGI.escape(name)
      if namespace?
        Gitlab::Routing.url_helpers.edit_group_security_policy_url(namespace, id: id, type: type)
      else
        Gitlab::Routing.url_helpers.edit_project_security_policy_url(project, id: id, type: type)
      end
    end

    def pipeline_execution_ci_config
      content&.dig('content', 'include', 0)
    end

    def policy_content
      content.deep_symbolize_keys
    end
    strong_memoize_attr :policy_content

    def warn_mode?
      actions = content&.dig('actions')
      return false unless actions

      require_approval_actions = actions.select do |action|
        action['type'] == Security::ScanResultPolicy::REQUIRE_APPROVAL
      end

      return false unless require_approval_actions.present?

      require_approval_actions.all? do |action|
        action['approvals_required'] == 0
      end
    end

    def enforced_scans
      metadata.fetch('enforced_scans', [])
    end

    def enforced_scans=(scans)
      metadata['enforced_scans'] = scans
    end

    def bypass_settings
      Security::ScanResultPolicies::BypassSettings.new(policy_content[:bypass_settings])
    end
    strong_memoize_attr :bypass_settings

    def supports_policy_rules?
      Security::PolicyRule::SUPPORTED_POLICY_TYPES.include?(type.to_sym)
    end

    private

    def content_by_type
      content_hash = content.deep_symbolize_keys.slice(*POLICY_CONTENT_FIELDS[type.to_sym])

      return content_hash unless supports_policy_rules?

      content_hash.merge(rules: rules.map(&:typed_content).map(&:deep_symbolize_keys))
    end

    def link_policy_rules_project!(project, policy_rules = approval_policy_rules.undeleted)
      return if !type_approval_policy? || policy_rules.empty?

      Security::ApprovalPolicyRuleProjectLink.insert_all(
        policy_rules.map { |policy_rule| { approval_policy_rule_id: policy_rule.id, project_id: project.id } },
        unique_by: [:approval_policy_rule_id, :project_id]
      )
    end

    def unlink_policy_rules_project!(project, policy_rules = approval_policy_rules)
      return if !type_approval_policy? || policy_rules.empty?

      Security::ApprovalPolicyRuleProjectLink.for_project(project).for_policy_rules(policy_rules).delete_all
    end

    def delete_approval_rules
      policy_configuration = security_orchestration_policy_configuration
      policy_configuration.approval_project_rules.each_batch do |project_rules_batch|
        project_rules_batch.where(approval_policy_rule_id: approval_policy_rules.select(:id)).delete_all
      end

      policy_configuration.approval_merge_request_rules.each_batch(order_hint: :updated_at) do |mr_rules_batch|
        mr_rules_batch
          .for_unmerged_merge_requests
          .where(approval_policy_rules: approval_policy_rules.select(:id))
          .delete_all
      end
    end

    def delete_policy_violations
      delete_in_batches(
        Security::ScanResultPolicyViolation.where(approval_policy_rule_id: approval_policy_rules.select(:id))
      )
    end

    def delete_software_license_policies
      delete_in_batches(SoftwareLicensePolicy.where(approval_policy_rule_id: approval_policy_rules.select(:id)))
    end

    def delete_in_batches(relation)
      relation.each_batch do |batch|
        batch.delete_all
      end
    end
  end
end
