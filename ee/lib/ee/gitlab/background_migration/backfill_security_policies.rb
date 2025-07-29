# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module BackfillSecurityPolicies
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          operation_name :backfill_security_policies
        end

        class ComplianceFrameworkSetting < ::ApplicationRecord
          self.table_name = 'project_compliance_framework_settings'

          belongs_to :project, class_name: 'Project'
        end

        class Route < ::ApplicationRecord
          self.table_name = 'routes'
        end

        module Routable
          extend ActiveSupport::Concern

          included do
            has_one :route, as: :source
          end

          def full_path
            route&.path || build_full_path
          end

          def build_full_path
            if parent && path
              "#{parent.full_path}/#{path}"
            else
              path
            end
          end
        end

        class Project < ::ApplicationRecord
          include Routable

          self.table_name = 'projects'

          belongs_to :parent, class_name: '::EE::Gitlab::BackgroundMigration::BackfillSecurityPolicies::Namespace'
          has_one :route, as: :source, class_name: '::EE::Gitlab::BackgroundMigration::BackfillSecurityPolicies::Route'
          has_many :compliance_framework_settings, class_name: 'ComplianceFrameworkSetting', inverse_of: :project
          belongs_to :namespace
          belongs_to :group, -> { where(type: Group::GROUP_STI_NAME) }, foreign_key: 'namespace_id'

          # rubocop:disable Database/AvoidUsingPluckWithoutLimit -- this is also used in the original class:
          # https://gitlab.com/gitlab-org/gitlab/-/blob/f4b8d8936ffe111af417b1e2f36d9aba4462a53b/ee/app/models/ee/project.rb?page=2#L1404
          def compliance_framework_ids
            compliance_framework_settings.pluck(:framework_id)
          end
          # rubocop:enable Database/AvoidUsingPluckWithoutLimit

          def default_branch_or_main
            return default_branch if default_branch

            'main'
          end

          def repository
            @repository ||= Repository.new(full_path, self, shard: repository_storage, disk_path: storage.disk_path)
          end

          private

          def default_branch
            @default_branch ||= repository.root_ref || default_branch_from_preferences
          end

          def storage
            @storage ||=
              if hashed_repository_storage?
                Storage::Hashed.new(self)
              else
                Storage::LegacyProject.new(self)
              end
          end

          def hashed_repository_storage?
            storage_version.to_i >= 1
          end

          def default_branch_from_preferences
            ::Gitlab::CurrentSettings.default_branch_name if repository.empty?
          end
        end

        # This class depends on following classes
        #   GlRepository class defined in `lib/gitlab/gl_repository.rb`
        #   Repository class defined in `lib/gitlab/git/repository.rb`.
        class Repository
          def initialize(full_path, container, shard:, disk_path: nil, repo_type: ::Gitlab::GlRepository::PROJECT)
            @full_path = full_path
            @shard = shard
            @disk_path = disk_path || full_path
            @container = container
            @commit_cache = {}
            @repo_type = repo_type
          end

          def blob_data_at(sha, path)
            blob = blob_at(sha, path)
            return unless blob

            blob.load_all_data!
            blob.data
          end

          def root_ref
            raw_repository&.root_ref
          rescue ::Gitlab::Git::Repository::NoRepository
          end

          def empty?
            return true unless exists?

            !has_visible_content?
          end

          private

          def blob_at(sha, path, limit: ::Gitlab::Git::Blob::MAX_DATA_DISPLAY_SIZE)
            Blob.decorate(raw_repository.blob_at(sha, path, limit: limit), container)
          rescue ::Gitlab::Git::Repository::NoRepository
            nil
          end

          attr_reader :full_path, :shard, :disk_path, :container, :repo_type

          delegate :has_visible_content?, to: :raw_repository, private: true

          def exists?
            return false unless full_path

            raw_repository.exists?
          end

          def raw_repository
            return unless full_path

            @raw_repository ||= initialize_raw_repository
          end

          def initialize_raw_repository
            ::Gitlab::Git::Repository.new(
              shard,
              "#{disk_path}.git",
              repo_type.identifier_for_container(container),
              container.full_path,
              container: container
            )
          end
        end

        class Namespace < ::ApplicationRecord
          include Routable

          self.table_name = 'namespaces'
          self.inheritance_column = :_type_disabled

          belongs_to :parent, class_name: '::EE::Gitlab::BackgroundMigration::BackfillSecurityPolicies::Namespace'
        end

        module Storage
          class Hashed
            attr_accessor :container

            REPOSITORY_PATH_PREFIX = '@hashed'

            def initialize(container)
              @container = container
            end

            def base_dir
              "#{REPOSITORY_PATH_PREFIX}/#{disk_hash[0..1]}/#{disk_hash[2..3]}" if disk_hash
            end

            def disk_path
              "#{base_dir}/#{disk_hash}" if disk_hash
            end

            private

            def disk_hash
              @disk_hash ||= Digest::SHA2.hexdigest(container.id.to_s) if container.id
            end
          end

          class LegacyProject
            attr_accessor :project

            def initialize(project)
              @project = project
            end

            def disk_path
              project.full_path
            end
          end
        end

        class Group < ::ApplicationRecord
          self.table_name = 'namespaces'
          self.inheritance_column = :_type_disabled

          include ::Namespaces::Traversal::Recursive

          USER_STI_NAME = 'User'
          GROUP_STI_NAME = 'Group'
          PROJECT_STI_NAME = 'Project'

          def all_projects
            # It should not be possible to create security policies for a user namespace but
            # at the time this migration is created there is no validation that makes sure
            # namespace is a group.
            namespace = user_namespace? ? self : self_and_descendant_ids
            Project.where(namespace: namespace)
          end

          private

          def user_namespace?
            # That last bit ensures we're considered a user namespace as a default
            type.nil? || type == USER_STI_NAME || !(type == GROUP_STI_NAME || type == PROJECT_STI_NAME)
          end
        end

        class SecurityOrchestrationPolicyConfiguration < ::ApplicationRecord
          include ::Gitlab::Utils::StrongMemoize

          self.table_name = 'security_orchestration_policy_configurations'

          POLICY_PATH = '.gitlab/security-policies/policy.yml'
          POLICY_SCHEMA_PATH = 'ee/app/validators/json_schemas/security_orchestration_policy.json'
          POLICY_SCHEMA = JSONSchemer.schema(Rails.root.join(POLICY_SCHEMA_PATH))
          SCAN_RESULT_POLICY_TYPES = %i[scan_result_policy approval_policy].freeze

          belongs_to :project, class_name: 'Project', optional: true
          belongs_to :namespace, class_name: 'Group', optional: true

          belongs_to :security_policy_management_project, class_name: 'Project'
          has_many :security_policies, class_name: 'SecurityPolicy'

          def policy_repo
            security_policy_management_project.repository
          end

          def policy_hash
            policy_yaml
          end
          strong_memoize_attr :policy_hash

          def policy_yaml
            policy_blob = policy_repo.blob_data_at(default_branch_or_main, POLICY_PATH)
            return if policy_blob.blank?

            ::Gitlab::Config::Loader::Yaml.new(policy_blob).load!
          rescue ::Gitlab::Config::Loader::FormatError
            nil
          end

          def all_projects
            if namespace_id.present?
              namespace.all_projects
            else
              Project.id_in(project_id)
            end
          end
          strong_memoize_attr :all_projects

          def approval_policies
            SCAN_RESULT_POLICY_TYPES.flat_map do |type|
              policy_by_type(type).map do |policy|
                policy.tap { |p| p[:type] = type.to_s }
              end
            end
          end

          def scan_execution_policies
            policy_by_type(:scan_execution_policy)
          end

          def pipeline_execution_policies
            policy_by_type(:pipeline_execution_policy)
          end

          def vulnerability_management_policies
            policy_by_type(:vulnerability_management_policy)
          end

          def policy_by_type(type_or_types)
            return [] if policy_hash.blank?

            policy_hash.values_at(*Array.wrap(type_or_types).map(&:to_sym)).flatten.compact
          end

          def policy_configuration_valid?
            POLICY_SCHEMA.valid?(policy_hash.to_h.deep_stringify_keys)
          end

          def default_branch_or_main
            security_policy_management_project.default_branch_or_main
          end
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

          has_many :approval_policy_rules, class_name: 'ApprovalPolicyRule'
          has_many :scan_execution_policy_rules, class_name: 'ScanExecutionPolicyRule'
          has_many :vulnerability_management_policy_rules, class_name: 'VulnerabilityManagementPolicyRule'

          POLICY_CONTENT_FIELDS = {
            approval_policy: %i[actions approval_settings fallback_behavior policy_tuning],
            scan_execution_policy: %i[actions],
            pipeline_execution_policy: %i[content pipeline_config_strategy suffix],
            vulnerability_management_policy: %i[actions]
          }.freeze

          POLICY_RULE_CLASS = {
            approval_policy: 'ApprovalPolicyRule',
            scan_execution_policy: 'ScanExecutionPolicyRule',
            vulnerability_management_policy: 'VulnerabilityManagementPolicyRule'
          }.freeze

          def self.attributes_from_policy_hash(policy_type, policy_index, policy_hash, policy_configuration)
            {
              type: policy_type,
              policy_index: policy_index,
              name: policy_hash[:name],
              description: policy_hash[:description],
              enabled: policy_hash[:enabled],
              metadata: policy_hash.fetch(:metadata, {}),
              scope: policy_hash.fetch(:policy_scope, {}),
              content: policy_hash.slice(*POLICY_CONTENT_FIELDS[policy_type]),
              checksum: Digest::SHA256.hexdigest(policy_hash.to_json),
              security_policy_management_project_id: policy_configuration.security_policy_management_project_id
            }.compact
          end

          def self.create_policy(policy_configuration, policy_type, policy_hash, policy_index)
            policy = policy_configuration.security_policies.create!(
              attributes_from_policy_hash(policy_type, policy_index, policy_hash, policy_configuration)
            )

            module_name = Module.nesting[1] # EE::Gitlab::BackgroundMigration::BackfillSecurityPolicies
            rule_class = "#{module_name}::#{POLICY_RULE_CLASS[policy_type]}".safe_constantize

            return policy unless rule_class

            Array.wrap(policy_hash[:rules]).map.with_index do |rule_hash, rule_index|
              rule_class.create!(
                type: rule_hash[:type],
                content: rule_hash.without(:type),
                security_policy_id: policy.id,
                rule_index: rule_index,
                security_policy_management_project_id: policy_configuration.security_policy_management_project_id
              )
            end

            policy
          end
        end

        class SecurityPolicyProjectLink < ::ApplicationRecord
          self.table_name = 'security_policy_project_links'
        end

        class ApprovalPolicyRule < ::ApplicationRecord
          self.table_name = 'approval_policy_rules'
          self.inheritance_column = :_type_disabled

          enum :type, { scan_finding: 0, license_finding: 1, any_merge_request: 2 }, prefix: true
        end

        class ScanExecutionPolicyRule < ::ApplicationRecord
          self.table_name = 'scan_execution_policy_rules'
          self.inheritance_column = :_type_disabled

          enum :type, { pipeline: 0, schedule: 1 }, prefix: true
        end

        class VulnerabilityManagementPolicyRule < ::ApplicationRecord
          self.table_name = 'vulnerability_management_policy_rules'
          self.inheritance_column = :_type_disabled

          enum :type, { no_longer_detected: 0 }, prefix: true
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

            return false if policy_scope_excluded_projects.any? { |policy_project| policy_project[:id] == project.id }
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
            SecurityOrchestrationPolicyConfiguration.id_in(sub_batch).each do |policy_configuration|
              next unless policy_configuration.policy_configuration_valid?

              create_policies(policy_configuration)
            end
          end
        end

        private

        def create_policies(policy_configuration)
          approval_policies = policy_configuration.approval_policies
          scan_execution_policies = policy_configuration.scan_execution_policies
          pipeline_execution_policies = policy_configuration.pipeline_execution_policies
          vulnerability_management_policies = policy_configuration.vulnerability_management_policies

          db_policies = policy_configuration.security_policies
          yaml_policies_count = approval_policies.count + scan_execution_policies.count +
            pipeline_execution_policies.count + vulnerability_management_policies.count

          # policies already persisted in database
          return if db_policies.count == yaml_policies_count

          create_policies_by_type(db_policies, policy_configuration, approval_policies, :approval_policy)
          create_policies_by_type(db_policies, policy_configuration, scan_execution_policies, :scan_execution_policy)
          create_policies_by_type(db_policies, policy_configuration, pipeline_execution_policies,
            :pipeline_execution_policy)
          create_policies_by_type(db_policies, policy_configuration, vulnerability_management_policies,
            :vulnerability_management_policy)
        end

        def create_policies_by_type(db_policies, policy_configuration, yaml_policies, policy_type)
          db_policies_by_index = db_policies
            .select { |policy| policy.type == policy_type.to_s }
            .group_by(&:policy_index)

          yaml_policies.each_with_index do |policy_hash, index|
            next if db_policies_by_index[index]

            security_policy = SecurityPolicy.create_policy(policy_configuration, policy_type, policy_hash, index)
            link_policy_to_project(policy_configuration, security_policy)
          end
        end

        def link_policy_to_project(policy_configuration, security_policy)
          policy_configuration.all_projects.find_each do |project|
            next unless security_policy.enabled?
            next unless PolicyScopeChecker.new(project: project).security_policy_applicable?(security_policy)

            SecurityPolicyProjectLink.create!(security_policy_id: security_policy.id, project_id: project.id)

            next unless security_policy.type_approval_policy?

            attrs = security_policy.approval_policy_rules.map do |policy_rule|
              { approval_policy_rule_id: policy_rule.id, project_id: project.id }
            end

            next if attrs.empty?

            ApprovalPolicyRuleProjectLink.insert_all(attrs, unique_by: [:approval_policy_rule_id, :project_id])
          end
        end
      end
    end
  end
end
