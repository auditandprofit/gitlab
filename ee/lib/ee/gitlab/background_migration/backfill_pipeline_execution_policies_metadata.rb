# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      # rubocop:disable Layout/LineLength -- long class names inside the migration
      module BackfillPipelineExecutionPoliciesMetadata
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        DELAY_INTERVAL = 10.seconds

        prepended do
          operation_name :backfill_pipeline_execution_policies_metadata
          scope_to ->(relation) { relation.where('type = 2') }
        end

        class User < ::ApplicationRecord
          self.table_name = 'users'
        end

        class MergeRequestMetrics < ::ApplicationRecord
          self.table_name = 'merge_request_metrics'

          belongs_to :merge_request, inverse_of: :metrics, class_name: '::EE::Gitlab::BackgroundMigration::BackfillPipelineExecutionPoliciesMetadata::MergeRequest'
        end

        class MergeRequest < ::ApplicationRecord
          self.table_name = 'merge_requests'

          scope :merged, -> { where(state_id: 3) }
          scope :order_by_metric, ->(metric, direction) do
            order = order_by_metric_column(metric, direction)
            order.apply_cursor_conditions(join_metrics).order(order)
          end
          scope :order_merged_at_desc, -> { order_by_metric(:merged_at, 'DESC') }
          scope :join_metrics, -> do
            project_condition = MergeRequest.arel_table[:target_project_id].eq(MergeRequestMetrics.arel_table[:target_project_id])
            joins(:metrics).where(project_condition)
          end

          belongs_to :author, class_name: '::EE::Gitlab::BackgroundMigration::BackfillPipelineExecutionPoliciesMetadata::User'
          has_one :metrics, inverse_of: :merge_request, class_name: '::EE::Gitlab::BackgroundMigration::BackfillPipelineExecutionPoliciesMetadata::MergeRequestMetrics'
          belongs_to :target_project,
            class_name: '::EE::Gitlab::BackgroundMigration::BackfillPipelineExecutionPoliciesMetadata::Project',
            inverse_of: :merge_requests

          def self.order_by_metric_column(metric, direction)
            column_expression = MergeRequestMetrics.arel_table[metric]
            column_expression_with_direction = direction == 'ASC' ? column_expression.asc : column_expression.desc

            ::Gitlab::Pagination::Keyset::Order.build(
              [
                ::Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
                  attribute_name: "merge_request_metrics_#{metric}",
                  column_expression: column_expression,
                  order_expression: column_expression_with_direction.nulls_last,
                  reversed_order_expression: column_expression_with_direction.reverse.nulls_first,
                  order_direction: direction,
                  nullable: :nulls_last,
                  add_to_projections: true
                ),
                ::Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
                  attribute_name: 'merge_request_metrics_id',
                  order_expression: MergeRequestMetrics.arel_table[:id].desc,
                  add_to_projections: true
                )
              ])
          end
        end

        class Project < ::ApplicationRecord
          self.table_name = 'projects'

          has_many :merge_requests, foreign_key: 'target_project_id',
            class_name: '::EE::Gitlab::BackgroundMigration::BackfillPipelineExecutionPoliciesMetadata::MergeRequest',
            inverse_of: :target_project
          has_one :security_orchestration_policy_configuration,
            class_name: '::EE::Gitlab::BackgroundMigration::BackfillPipelineExecutionPoliciesMetadata::SecurityOrchestrationPolicyConfiguration',
            inverse_of: :project
        end

        class SecurityOrchestrationPolicyConfiguration < ::ApplicationRecord
          self.table_name = 'security_orchestration_policy_configurations'
        end

        class PipelineExecutionPolicyConfigLink < ::ApplicationRecord
          self.table_name = 'security_pipeline_execution_policy_config_links'

          belongs_to :security_policy,
            class_name: '::EE::Gitlab::BackgroundMigration::BackfillPipelineExecutionPoliciesMetadata::SecurityPolicy',
            inverse_of: :security_pipeline_execution_policy_config_link
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

          belongs_to :security_orchestration_policy_configuration,
            class_name: '::EE::Gitlab::BackgroundMigration::BackfillPipelineExecutionPoliciesMetadata::SecurityOrchestrationPolicyConfiguration'
          has_one :security_pipeline_execution_policy_config_link,
            class_name: '::EE::Gitlab::BackgroundMigration::BackfillPipelineExecutionPoliciesMetadata::PipelineExecutionPolicyConfigLink',
            inverse_of: :security_policy
        end

        override :perform
        def perform
          delay = 0

          each_sub_batch do |sub_batch|
            policies = SecurityPolicy
              .id_in(sub_batch)
              .includes(:security_pipeline_execution_policy_config_link, :security_orchestration_policy_configuration)
              .to_a

            policy_project_ids = policies.map do |policy|
              policy.security_orchestration_policy_configuration.security_policy_management_project_id
            end.uniq

            authors_by_policy_projects = authors_by_project_id(policy_project_ids)

            policies.each do |policy|
              config_project_id = policy.security_pipeline_execution_policy_config_link&.project_id
              next unless config_project_id

              policy_project_id = policy.security_orchestration_policy_configuration.security_policy_management_project_id
              user_id = authors_by_policy_projects[policy_project_id]
              next unless user_id

              ::Security::SyncPipelineExecutionPolicyMetadataWorker
                .perform_in(delay, config_project_id, user_id, policy.content['content'], [policy.id])

              delay += DELAY_INTERVAL
            end
          end
        end

        private

        def authors_by_project_id(project_ids)
          return {} if project_ids.empty?

          # Using the same scope as in OrchestrationPolicyConfiguration#policy_last_updated_by
          MergeRequest.select('DISTINCT ON (merge_requests.target_project_id) merge_requests.target_project_id, merge_requests.author_id')
                      .merged
                      .order(:target_project_id).order_merged_at_desc
                      .where(target_project_id: project_ids)
                      .to_h { |merge_request| [merge_request.target_project_id, merge_request.author_id] }
        end
      end
      # rubocop:enable Layout/LineLength
    end
  end
end
