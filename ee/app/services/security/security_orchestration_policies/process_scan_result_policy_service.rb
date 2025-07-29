# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class ProcessScanResultPolicyService
      include ::Gitlab::Utils::StrongMemoize
      include Gitlab::InternalEventsTracking

      REPORT_TYPE_MAPPING = {
        Security::ScanResultPolicy::LICENSE_FINDING => :license_scanning,
        Security::ScanResultPolicy::ANY_MERGE_REQUEST => :any_merge_request
      }.freeze

      def initialize(project:, policy_configuration:, policy:, policy_index:, real_policy_index:)
        @policy_configuration = policy_configuration
        @policy = policy
        @policy_index = policy_index
        @real_policy_index = real_policy_index
        @project = project
        @author = policy_configuration.policy_last_updated_by
      end

      def execute
        create_new_approval_rules
        track_multiple_approval_actions
      end

      private

      attr_reader :policy_configuration, :policy, :project, :author, :policy_index, :real_policy_index

      def track_multiple_approval_actions
        return unless approval_actions.size > 1

        track_internal_event('check_multiple_approval_actions_for_approval_policy', project: project)
      end

      def track_approval_rule_creation(rule_type)
        track_internal_event(
          'create_approval_rule_from_merge_request_approval_policy',
          project: project,
          additional_properties: {
            label: rule_type # Type of the Merge Request Approval Policy
          }
        )
      end

      def create_new_approval_rules
        policy[:rules]&.first(Security::ScanResultPolicy::RULES_LIMIT)&.each_with_index do |rule, rule_index|
          next unless rule_type_allowed?(rule[:type])

          track_approval_rule_creation(rule[:type])

          if approval_actions.empty?
            process_rule(rule, rule_index)
            next
          end

          approval_actions.each_with_index do |approval_action, action_index|
            process_rule(rule, rule_index, approval_action, action_index)
          end
        end
      end

      def process_rule(rule, rule_index, approval_action = nil, action_index = 0)
        approval_policy_rule = Security::ApprovalPolicyRule.by_policy_rule_index(
          policy_configuration, policy_index: real_policy_index, rule_index: rule_index
        )

        scan_result_policy_read = create_scan_result_policy(
          rule, approval_policy_rule, approval_action, rule_index, action_index
        )

        create_software_license_policies(rule, scan_result_policy_read, approval_policy_rule) if create_licenses?(rule)

        return unless create_approval_rule?(rule)

        ::ApprovalRules::CreateService.new(project, author,
          rule_params(
            rule, rule_index, approval_action, scan_result_policy_read, approval_policy_rule, action_index
          )
        ).execute
      end

      def send_bot_message_action
        policy[:actions]&.find do |action|
          action[:type] == Security::ScanResultPolicy::SEND_BOT_MESSAGE
        end
      end
      strong_memoize_attr :send_bot_message_action

      def approval_actions
        Array.wrap(policy[:actions]&.select { |action| action[:type] == Security::ScanResultPolicy::REQUIRE_APPROVAL })
      end
      strong_memoize_attr :approval_actions

      def create_approval_rule?(rule)
        return true if rule[:type] != Security::ScanResultPolicy::ANY_MERGE_REQUEST

        # For `any_merge_request` rules, the approval rules can be created without approvers and can override
        # project approval settings in general.
        # The violations in this case are handled via SyncAnyMergeRequestRulesService
        approval_actions.present?
      end

      def create_licenses?(rule)
        rule[:type] == Security::ScanResultPolicy::LICENSE_FINDING && rule[:license_types].present?
      end

      def create_software_license_policies(rule, scan_result_policy_read, approval_policy_rule)
        create_software_license_params(rule, scan_result_policy_read, approval_policy_rule).each do |params|
          ::SoftwareLicensePolicies::CreateService
            .new(project, author, params)
            .execute
        end
      end

      def create_software_license_params(rule, scan_result_policy_read, approval_policy_rule)
        rule[:license_types].map do |license_type|
          {
            name: license_type,
            approval_status: rule[:match_on_inclusion_license] ? 'denied' : 'allowed',
            scan_result_policy_read: scan_result_policy_read,
            approval_policy_rule_id: approval_policy_rule&.id
          }
        end
      end

      def create_scan_result_policy(rule, approval_policy_rule, approval_action, rule_index, action_index = 0)
        policy_configuration.scan_result_policy_reads.create!(
          orchestration_policy_idx: policy_index,
          rule_idx: rule_index,
          action_idx: action_index,
          license_states: rule[:license_states],
          match_on_inclusion_license: rule[:match_on_inclusion_license] || false,
          role_approvers: role_access_levels(approval_action&.dig(:role_approvers)),
          custom_roles: custom_role_approvers(approval_action&.dig(:role_approvers)),
          vulnerability_attributes: rule[:vulnerability_attributes],
          project_id: project.id,
          age_operator: rule.dig(:vulnerability_age, :operator),
          age_interval: rule.dig(:vulnerability_age, :interval),
          age_value: rule.dig(:vulnerability_age, :value),
          commits: rule[:commits],
          project_approval_settings: policy[:approval_settings] || {},
          send_bot_message: send_bot_message_action&.slice(:enabled) || {},
          fallback_behavior: policy.fetch(:fallback_behavior, {}),
          policy_tuning: policy.fetch(:policy_tuning, {}),
          licenses: rule.fetch(:licenses, {}),
          approval_policy_rule_id: approval_policy_rule&.id
        )
      end

      def rule_params(rule, rule_index, action_info, scan_result_policy_read, approval_policy_rule, action_index = 0)
        rule_params = {
          skip_authorization: true,
          approvals_required: action_info&.dig(:approvals_required) || 0,
          name: rule_name(policy[:name], rule_index),
          protected_branch_ids: protected_branch_ids(rule),
          applies_to_all_protected_branches: applies_to_all_protected_branches?(rule),
          rule_type: :report_approver,
          user_ids: users_ids(action_info&.dig(:user_approvers_ids), action_info&.dig(:user_approvers)),
          report_type: report_type(rule[:type]),
          orchestration_policy_idx: policy_index,
          group_ids: groups_ids(action_info&.dig(:group_approvers_ids), action_info&.dig(:group_approvers)),
          security_orchestration_policy_configuration_id: policy_configuration.id,
          scan_result_policy_id: scan_result_policy_read&.id,
          approval_policy_rule_id: approval_policy_rule&.id,
          approval_policy_action_idx: action_index,
          permit_inaccessible_groups: true
        }

        rule_params[:severity_levels] = [] if rule[:type] == Security::ScanResultPolicy::LICENSE_FINDING

        if rule[:type] == Security::ScanResultPolicy::SCAN_FINDING
          rule_params.merge!({
            scanners: rule[:scanners],
            severity_levels: rule[:severity_levels],
            vulnerabilities_allowed: rule[:vulnerabilities_allowed],
            vulnerability_states: rule[:vulnerability_states]
          })
        end

        rule_params
      end

      def protected_branch_ids(rule)
        service = Security::SecurityOrchestrationPolicies::PolicyBranchesService.new(project: project)
        applicable_branches = service.scan_result_branches([rule])
        protected_branches = project.all_protected_branches.select do |protected_branch|
          applicable_branches.any? { |branch| protected_branch.matches?(branch) }
        end

        protected_branches.pluck(:id) # rubocop: disable CodeReuse/ActiveRecord
      end

      def applies_to_all_protected_branches?(rule)
        rule[:branches] == [] || (rule[:branch_type] == "protected" && rule[:branch_exceptions].blank?)
      end

      def rule_type_allowed?(rule_type)
        [
          Security::ScanResultPolicy::SCAN_FINDING,
          Security::ScanResultPolicy::LICENSE_FINDING,
          Security::ScanResultPolicy::ANY_MERGE_REQUEST
        ].include?(rule_type)
      end

      def report_type(rule_type)
        REPORT_TYPE_MAPPING.fetch(rule_type, :scan_finding)
      end

      def rule_name(policy_name, rule_index)
        return policy_name if rule_index == 0

        "#{policy_name} #{rule_index + 1}"
      end

      def users_ids(user_ids, user_names)
        project.team.users.get_ids_by_ids_or_usernames(user_ids, user_names)
      end

      def groups_ids(group_ids, group_paths)
        Security::ApprovalGroupsFinder.new(group_ids: group_ids,
          group_paths: group_paths,
          user: author,
          container: project.namespace,
          search_globally: search_groups_globally?).execute(include_inaccessible: true)
      end

      def custom_role_approvers(role_approvers)
        return [] unless role_approvers

        role_approvers.select { |role| role.is_a?(Integer) }
      end

      def role_access_levels(role_approvers)
        return [] unless role_approvers

        roles_map = Gitlab::Access.sym_options_with_owner
        role_approvers
          .filter_map { |role| roles_map[role.to_sym] if role.to_s.in?(Security::ScanResultPolicy::ALLOWED_ROLES) }
      end

      def search_groups_globally?
        Gitlab::CurrentSettings.security_policy_global_group_approvers_enabled?
      end
    end
  end
end
