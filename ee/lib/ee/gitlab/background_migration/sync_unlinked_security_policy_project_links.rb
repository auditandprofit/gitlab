# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module SyncUnlinkedSecurityPolicyProjectLinks
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          operation_name :sync_unlinked_security_policy_project_links
        end

        class Namespace < ::ApplicationRecord
          self.table_name = 'namespaces'
          self.inheritance_column = :_type_disabled

          belongs_to :parent,
            class_name: '::EE::Gitlab::BackgroundMigration::SyncUnlinkedSecurityPolicyProjectLinks::Namespace'
        end

        class ProjectNamespace < ::ApplicationRecord
          self.table_name = 'namespaces'
          self.inheritance_column = :_type_disabled

          PROJECT_STI_NAME = 'Project'
        end

        class Group < ::ApplicationRecord
          self.table_name = 'namespaces'
          self.inheritance_column = :_type_disabled

          include ::Namespaces::Traversal::Recursive # Added to fix failing static analysis pipeline
          include ::Namespaces::Traversal::Linear
          include ::Namespaces::Traversal::Cached

          GROUP_STI_NAME = 'Group'
        end

        class Project < ::ApplicationRecord
          self.table_name = 'projects'

          belongs_to :parent,
            class_name: '::EE::Gitlab::BackgroundMigration::SyncUnlinkedSecurityPolicyProjectLinks::Namespace'

          has_many :compliance_framework_settings, class_name:
            '::EE::Gitlab::BackgroundMigration::SyncUnlinkedSecurityPolicyProjectLinks::ComplianceFrameworkSetting',
            inverse_of: :project
          belongs_to :namespace,
            class_name: '::EE::Gitlab::BackgroundMigration::SyncUnlinkedSecurityPolicyProjectLinks::Namespace'
          belongs_to :group, -> { where(type: Group::GROUP_STI_NAME) },
            foreign_key: 'namespace_id',
            class_name: '::EE::Gitlab::BackgroundMigration::SyncUnlinkedSecurityPolicyProjectLinks::Group'

          # rubocop:disable Database/AvoidUsingPluckWithoutLimit -- this is also used in the original class:
          # https://gitlab.com/gitlab-org/gitlab/-/blob/f4b8d8936ffe111af417b1e2f36d9aba4462a53b/ee/app/models/ee/project.rb?page=2#L1404
          def compliance_framework_ids
            compliance_framework_settings.pluck(:framework_id)
          end
          # rubocop:enable Database/AvoidUsingPluckWithoutLimit
        end

        class ComplianceFrameworkSetting < ::ApplicationRecord
          self.table_name = 'project_compliance_framework_settings'

          belongs_to :project,
            class_name: '::EE::Gitlab::BackgroundMigration::SyncUnlinkedSecurityPolicyProjectLinks::Project'
        end

        class SecurityOrchestrationPolicyConfiguration < ::ApplicationRecord
          include ::Gitlab::Utils::StrongMemoize

          self.table_name = 'security_orchestration_policy_configurations'

          belongs_to :project,
            class_name: '::EE::Gitlab::BackgroundMigration::SyncUnlinkedSecurityPolicyProjectLinks::Project',
            optional: true
          belongs_to :namespace,
            class_name: '::EE::Gitlab::BackgroundMigration::SyncUnlinkedSecurityPolicyProjectLinks::Group',
            optional: true
          has_many :security_policies,
            class_name: '::EE::Gitlab::BackgroundMigration::SyncUnlinkedSecurityPolicyProjectLinks::SecurityPolicy'

          def all_projects
            if namespace_id.present?
              projects = []
              cursor = { current_id: namespace_id, depth: [namespace_id] }
              iterator = ::Gitlab::Database::NamespaceEachBatch.new(namespace_class: ::Namespace, cursor: cursor)

              iterator.each_batch(of: 1000) do |ids|
                namespace_ids = ProjectNamespace.where(id: ids, type: ProjectNamespace::PROJECT_STI_NAME)
                projects.concat(Project.where(project_namespace_id: namespace_ids))
              end
              projects
            else
              Array.wrap(Project.find(project_id))
            end
          end
          strong_memoize_attr :all_projects
        end

        class SecurityPolicy < ::ApplicationRecord
          self.table_name = 'security_policies'
          self.inheritance_column = :_type_disabled

          enum :type, {
            approval_policy: 0,
            scan_execution_policy: 1,
            pipeline_execution_policy: 2,
            vulnerability_management_policy: 3
          }, prefix: true

          # rubocop:disable Layout/LineLength -- the name is long
          belongs_to :security_orchestration_policy_configuration, class_name:
            '::EE::Gitlab::BackgroundMigration::SyncUnlinkedSecurityPolicyProjectLinks::SecurityOrchestrationPolicyConfiguration'
          # rubocop:enable Layout/LineLength
          has_many :approval_policy_rules,
            class_name: '::EE::Gitlab::BackgroundMigration::SyncUnlinkedSecurityPolicyProjectLinks::ApprovalPolicyRule'
        end

        class SecurityPolicyProjectLink < ::ApplicationRecord
          self.table_name = 'security_policy_project_links'
        end

        class ApprovalPolicyRule < ::ApplicationRecord
          self.table_name = 'approval_policy_rules'
          self.inheritance_column = :_type_disabled

          enum :type, { scan_finding: 0, license_finding: 1, any_merge_request: 2 }, prefix: true
        end

        class ApprovalPolicyRuleProjectLink < ::ApplicationRecord
          self.table_name = 'approval_policy_rule_project_links'
        end

        # This is copied from Security::SecurityOrchestrationPolicies::PolicyScopeChecker
        class PolicyScopeChecker
          def initialize(project:)
            @project = project
          end

          def security_policy_applicable?(security_policy)
            return false if security_policy.blank?
            return true if security_policy.scope.blank?

            scope_applicable?(security_policy.scope.deep_symbolize_keys)
          end

          private

          attr_accessor :project

          def scope_applicable?(policy_scope)
            applicable_for_compliance_framework?(policy_scope) &&
              applicable_for_project?(policy_scope) &&
              applicable_for_group?(policy_scope)
          end

          def applicable_for_compliance_framework?(policy_scope)
            policy_scope_compliance_frameworks = policy_scope[:compliance_frameworks].to_a
            return true if policy_scope_compliance_frameworks.blank?

            compliance_framework_ids = project.compliance_framework_ids
            return false if compliance_framework_ids.blank?

            policy_scope_compliance_frameworks.any? { |framework| framework[:id].in?(compliance_framework_ids) }
          end

          def applicable_for_project?(policy_scope)
            policy_scope_included_projects = policy_scope.dig(:projects, :including).to_a
            policy_scope_excluded_projects = policy_scope.dig(:projects, :excluding).to_a

            return false if policy_scope_excluded_projects.any? do |policy_project|
              policy_project[:id] == project.id
            end

            return true if policy_scope_included_projects.blank?

            policy_scope_included_projects.any? { |policy_project| policy_project[:id] == project.id }
          end

          def applicable_for_group?(policy_scope)
            policy_scope_included_groups = policy_scope.dig(:groups, :including).to_a
            policy_scope_excluded_groups = policy_scope.dig(:groups, :excluding).to_a

            return true if policy_scope_included_groups.blank? && policy_scope_excluded_groups.blank?

            ancestor_group_ids = project.group&.self_and_ancestor_ids.to_a

            return false if policy_scope_excluded_groups.any? do |policy_group|
              policy_group[:id].in?(ancestor_group_ids)
            end

            return true if policy_scope_included_groups.blank?

            policy_scope_included_groups.any? { |policy_group| policy_group[:id].in?(ancestor_group_ids) }
          end
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            SecurityPolicy.id_in(sub_batch.where(enabled: true)).each do |security_policy|
              process_security_policy(security_policy)
            end
          end
        end

        private

        def process_security_policy(security_policy)
          policy_configuration = security_policy.security_orchestration_policy_configuration
          applicable_project_ids = find_applicable_project_ids(policy_configuration, security_policy)

          return if applicable_project_ids.blank?

          applicable_project_ids.each_slice(1000) do |project_ids|
            create_policy_links(security_policy, project_ids)
            create_approval_policy_links(security_policy, project_ids) if security_policy.type_approval_policy?
          end
        end

        def find_applicable_project_ids(policy_configuration, security_policy)
          policy_configuration.all_projects.select do |project|
            PolicyScopeChecker.new(project: project).security_policy_applicable?(security_policy)
          end.map(&:id)
        end

        def create_policy_links(security_policy, project_ids)
          records = project_ids.map do |project_id|
            { security_policy_id: security_policy.id, project_id: project_id }
          end

          return if records.blank?

          SecurityPolicyProjectLink.insert_all(records, unique_by: [:security_policy_id, :project_id])
        end

        def create_approval_policy_links(security_policy, project_ids)
          policy_rules_records = security_policy.approval_policy_rules.flat_map do |rule|
            project_ids.map do |project_id|
              { approval_policy_rule_id: rule.id, project_id: project_id }
            end
          end

          return if policy_rules_records.blank?

          ApprovalPolicyRuleProjectLink.insert_all(policy_rules_records,
            unique_by: [:approval_policy_rule_id, :project_id])
        end
      end
    end
  end
end
