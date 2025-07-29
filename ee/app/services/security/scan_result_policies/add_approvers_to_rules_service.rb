# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class AddApproversToRulesService < BaseProjectService
      INSERT_BATCH_SIZE = 100
      APPROVAL_RULES_ATTRIBUTES = %i[id orchestration_policy_idx].freeze

      def execute(user_ids)
        params = build_bulk_insert_params(user_ids)
        insert_users_to_approval_rules(params)
      end

      private

      def build_bulk_insert_params(user_ids)
        project_usernames = username_map(user_ids)

        project.all_security_orchestration_policy_configurations.flat_map do |configuration|
          policies = configuration.applicable_scan_result_policies_for_project(project)
          next if policies.blank?

          policy_indexes_for_users = policy_indexes_for_users(user_ids, policies, project_usernames)
          referenced_policy_indexes = policy_indexes_for_users.values.flatten.uniq
          next if referenced_policy_indexes.none?

          build_approval_rules_for_users(configuration, policy_indexes_for_users, referenced_policy_indexes)
        end.compact
      end

      def build_approval_rules_for_users(configuration, policy_indexes_for_users, referenced_policy_indexes)
        project_rules = rules_by_idx(approval_project_rules(configuration, referenced_policy_indexes))
        merge_request_rules = rules_by_idx(approval_merge_request_rules(configuration, referenced_policy_indexes))

        policy_indexes_for_users.map do |user_id, policy_indexes|
          project_rule_ids = project_rules.values_at(*policy_indexes).flatten.compact
          merge_request_rule_ids = merge_request_rules.values_at(*policy_indexes).flatten.compact

          build_user_approval_rules_params(user_id, project_rule_ids, merge_request_rule_ids)
        end
      end

      def rules_by_idx(approval_rules)
        approval_rules.group_by(&:orchestration_policy_idx).transform_values { |rules| rules.map(&:id) }
      end

      def policy_indexes_for_users(user_ids, policies, project_usernames)
        user_ids.select { |user_id| project_usernames[user_id].present? }.filter_map do |user_id|
          policy_indexes = policy_indexes_for_user(policies, project_usernames, user_id)
          next if policy_indexes.none?

          [user_id, policy_indexes]
        end.to_h
      end

      def policy_indexes_for_user(policies, usernames, user_id)
        policies.filter_map.with_index do |policy, index|
          index if policy[:actions]&.any? do |action|
            action[:user_approvers_ids]&.include?(user_id) || action[:user_approvers]&.include?(usernames[user_id])
          end
        end
      end

      def username_map(user_ids)
        project.team.users.id_in(user_ids).select(:id, :username).to_h { |user| [user.id, user.username] }
      end

      def build_user_approval_rules_params(user_id, project_rule_ids, merge_request_rule_ids)
        project_rule_params = build_project_rule_params(project_rule_ids, user_id)
        merge_request_rule_params = build_merge_request_rule_params(merge_request_rule_ids, user_id)

        [project_rule_params, merge_request_rule_params]
      end

      def insert_users_to_approval_rules(bulk_insert_params)
        ApplicationRecord.transaction do
          bulk_insert_params.each_slice(INSERT_BATCH_SIZE) do |params_batch|
            project_rule_params = params_batch.flat_map(&:first)
            merge_request_rule_params = params_batch.flat_map(&:second)

            ApprovalProjectRulesUser.insert_all(project_rule_params) if project_rule_params.present?
            ApprovalMergeRequestRulesUser.insert_all(merge_request_rule_params) if merge_request_rule_params.present?
          end
        end
      end

      def approval_project_rules(configuration, policy_indexes)
        configuration.approval_project_rules
                     .for_project(project.id).for_policy_index(policy_indexes).select(*APPROVAL_RULES_ATTRIBUTES)
      end

      def approval_merge_request_rules(configuration, policy_indexes)
        configuration.approval_merge_request_rules.for_unmerged_merge_requests
                     .for_merge_request_project(project.id).for_policy_index(policy_indexes)
                     .select(*APPROVAL_RULES_ATTRIBUTES)
      end

      def build_project_rule_params(approval_rule_ids, user_id)
        approval_rule_ids.map { |rule_id| { approval_project_rule_id: rule_id, user_id: user_id } }
      end

      def build_merge_request_rule_params(approval_rule_ids, user_id)
        approval_rule_ids.map { |rule_id| { approval_merge_request_rule_id: rule_id, user_id: user_id } }
      end
    end
  end
end
