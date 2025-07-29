# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module BackfillApprovalPolicyRuleIds
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          operation_name :backfill_approval_policy_rule_ids
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

        class Route < ::ApplicationRecord
          self.table_name = 'routes'
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

          belongs_to :parent, class_name: '::EE::Gitlab::BackgroundMigration::BackfillApprovalPolicyRuleIds::Namespace'
        end

        class Project < ::ApplicationRecord
          include Routable

          self.table_name = 'projects'

          belongs_to :parent,
            class_name: '::EE::Gitlab::BackgroundMigration::BackfillApprovalPolicyRuleIds::Namespace'

          has_one :route,
            as: :source,
            class_name: '::EE::Gitlab::BackgroundMigration::BackfillApprovalPolicyRuleIds::Route'

          has_many :security_policy_project_links,
            class_name: '::EE::Gitlab::BackgroundMigration::BackfillApprovalPolicyRuleIds::SecurityPolicyProjectLink'

          has_many :security_policies,
            class_name: '::EE::Gitlab::BackgroundMigration::BackfillApprovalPolicyRuleIds::SecurityPolicy',
            through: :security_policy_project_links

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

        class SecurityOrchestrationPolicyConfiguration < ::ApplicationRecord
          include ::Gitlab::Utils::StrongMemoize

          POLICY_PATH = '.gitlab/security-policies/policy.yml'
          SCAN_RESULT_POLICY_TYPES = %i[scan_result_policy approval_policy].freeze

          self.table_name = 'security_orchestration_policy_configurations'

          has_many :security_policies,
            class_name: '::EE::Gitlab::BackgroundMigration::BackfillApprovalPolicyRuleIds::SecurityPolicy'

          belongs_to :security_policy_management_project,
            class_name: '::EE::Gitlab::BackgroundMigration::BackfillApprovalPolicyRuleIds::Project'

          def approval_policy_hash
            SCAN_RESULT_POLICY_TYPES.flat_map do |type|
              policy_by_type(type).map do |policy|
                policy.tap { |p| p[:type] = type.to_s }
              end
            end
          end

          private

          def policy_yaml
            policy_blob = security_policy_management_project.repository.blob_data_at(
              default_branch_or_main, POLICY_PATH
            )
            return if policy_blob.blank?

            ::Gitlab::Config::Loader::Yaml.new(policy_blob).load!
          rescue ::Gitlab::Config::Loader::FormatError
            nil
          end
          strong_memoize_attr :policy_yaml

          def policy_by_type(type_or_types)
            return [] if policy_yaml.blank?

            policy_yaml.values_at(*Array.wrap(type_or_types).map(&:to_sym)).flatten.compact
          end

          def default_branch_or_main
            security_policy_management_project.default_branch_or_main
          end
        end

        class ScanResultPolicy < ::ApplicationRecord
          self.table_name = 'scan_result_policies'

          belongs_to :security_orchestration_policy_configuration, class_name:
            '::EE::Gitlab::BackgroundMigration::BackfillApprovalPolicyRuleIds::SecurityOrchestrationPolicyConfiguration'
          belongs_to :project,
            class_name: '::EE::Gitlab::BackgroundMigration::BackfillApprovalPolicyRuleIds::Project'
          has_many :approval_project_rules,
            class_name: '::EE::Gitlab::BackgroundMigration::BackfillApprovalPolicyRuleIds::ApprovalProjectRule'
          has_many :approval_merge_request_rules,
            class_name: '::EE::Gitlab::BackgroundMigration::BackfillApprovalPolicyRuleIds::ApprovalMergeRequestRule'
          has_many :software_license_policies,
            class_name: '::EE::Gitlab::BackgroundMigration::BackfillApprovalPolicyRuleIds::SoftwareLicensePolicy'
          has_many :scan_result_policy_violations,
            class_name: '::EE::Gitlab::BackgroundMigration::BackfillApprovalPolicyRuleIds::ScanResultPolicyViolation'

          def find_or_create_approval_policy_rule
            policy_configuration = security_orchestration_policy_configuration
            security_policies = project.security_policies
              .where(security_orchestration_policy_configuration_id: policy_configuration.id, type: 0)
              .order(policy_index: :asc)
              .limit(5)

            security_policy = security_policies.find { |policy| policy.policy_index == orchestration_policy_idx }

            # security_policies is not present in database
            return unless security_policy

            approval_policy_rule = find_approval_policy_rule(security_policy)
            return approval_policy_rule if approval_policy_rule

            create_approval_policy_rules_from_yaml(security_policy)
            find_approval_policy_rule(security_policy)
          end

          private

          def find_approval_policy_rule(security_policy)
            ApprovalPolicyRule.by_policy_rule_index(security_orchestration_policy_configuration,
              policy_index: security_policy.policy_index, rule_index: rule_idx
            )
          end

          def create_approval_policy_rules_from_yaml(security_policy)
            policy_configuration = security_orchestration_policy_configuration
            policy_from_yaml = policy_configuration.approval_policy_hash[security_policy.policy_index]
            return unless policy_from_yaml

            rules_from_yaml = policy_from_yaml[:rules]
            return unless rules_from_yaml

            rules_from_yaml.each_with_index do |rule_from_yaml, rule_index|
              attributes = {
                security_policy_id: security_policy.id,
                rule_index: rule_index,
                type: rule_from_yaml[:type],
                content: rule_from_yaml.except(:type),
                security_policy_management_project_id: policy_configuration.security_policy_management_project_id
              }

              ApprovalPolicyRule.upsert(
                attributes, unique_by: [:security_policy_id, :rule_index], returning: %w[id]
              )
            end
          end
        end

        class SecurityPolicy < ::ApplicationRecord
          self.table_name = 'security_policies'
          self.inheritance_column = :_type_disabled

          belongs_to :security_orchestration_policy_configuration, class_name:
            '::EE::Gitlab::BackgroundMigration::BackfillApprovalPolicyRuleIds::SecurityOrchestrationPolicyConfiguration'
          has_many :approval_policy_rules,
            class_name: '::EE::Gitlab::BackgroundMigration::BackfillApprovalPolicyRuleIds::ApprovalPolicyRule'
        end

        class ApprovalPolicyRule < ::ApplicationRecord
          self.table_name = 'approval_policy_rules'
          self.inheritance_column = :_type_disabled

          enum :type, { scan_finding: 0, license_finding: 1, any_merge_request: 2 }, prefix: true

          belongs_to :security_policy,
            class_name: '::EE::Gitlab::BackgroundMigration::BackfillApprovalPolicyRuleIds::SecurityPolicy'

          def self.by_policy_rule_index(policy_configuration, policy_index:, rule_index:)
            joins(:security_policy).find_by(
              rule_index: rule_index,
              security_policy: {
                security_orchestration_policy_configuration_id: policy_configuration.id,
                policy_index: policy_index
              }
            )
          end
        end

        class SecurityPolicyProjectLink < ::ApplicationRecord
          self.table_name = 'security_policy_project_links'

          belongs_to :security_policy,
            class_name: '::EE::Gitlab::BackgroundMigration::BackfillApprovalPolicyRuleIds::SecurityPolicy'
          belongs_to :project,
            class_name: '::EE::Gitlab::BackgroundMigration::BackfillApprovalPolicyRuleIds::Project'
        end

        class ApprovalProjectRule < ::ApplicationRecord
          self.table_name = 'approval_project_rules'

          belongs_to :scan_result_policy,
            class_name: '::EE::Gitlab::BackgroundMigration::BackfillApprovalPolicyRuleIds::ScanResultPolicy'
        end

        class ApprovalMergeRequestRule < ::ApplicationRecord
          self.table_name = 'approval_merge_request_rules'

          belongs_to :scan_result_policy,
            class_name: '::EE::Gitlab::BackgroundMigration::BackfillApprovalPolicyRuleIds::ScanResultPolicy'
        end

        class SoftwareLicensePolicy < ::ApplicationRecord
          self.table_name = 'software_license_policies'

          belongs_to :scan_result_policy,
            class_name: '::EE::Gitlab::BackgroundMigration::BackfillApprovalPolicyRuleIds::ScanResultPolicy'
        end

        class ScanResultPolicyViolation < ::ApplicationRecord
          self.table_name = 'scan_result_policy_violations'

          belongs_to :scan_result_policy,
            class_name: '::EE::Gitlab::BackgroundMigration::BackfillApprovalPolicyRuleIds::ScanResultPolicy'
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            ScanResultPolicy.id_in(sub_batch)
              .where(approval_policy_rule_id: nil).where.not(project_id: nil).find_each do |scan_result_policy|
                approval_policy_rule = scan_result_policy.find_or_create_approval_policy_rule
                next unless approval_policy_rule

                backfill_approval_policy_rule_ids(scan_result_policy, approval_policy_rule)
              end
          end
        end

        private

        def backfill_approval_policy_rule_ids(scan_result_policy, approval_policy_rule)
          scan_result_policy.update_column(:approval_policy_rule_id, approval_policy_rule.id)

          update_associated_records(scan_result_policy, approval_policy_rule)
        end

        def update_associated_records(scan_result_policy, approval_policy_rule)
          associations = [
            scan_result_policy.approval_project_rules,
            scan_result_policy.approval_merge_request_rules,
            scan_result_policy.software_license_policies,
            scan_result_policy.scan_result_policy_violations
          ]

          associations.each do |records|
            update_approval_policy_rule_ids(records, approval_policy_rule)
          end
        end

        def update_approval_policy_rule_ids(records, approval_policy_rule)
          return if records.empty?

          loop do
            update_count = records
              .where(approval_policy_rule_id: nil)
              .limit(1000)
              .update_all(approval_policy_rule_id: approval_policy_rule.id)

            break if update_count == 0
          end
        end
      end
    end
  end
end
