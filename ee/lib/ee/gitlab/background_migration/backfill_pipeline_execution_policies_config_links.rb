# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      # rubocop:disable Layout/LineLength -- unavoidable long class names
      module BackfillPipelineExecutionPoliciesConfigLinks
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        PIPELINE_EXECUTION_POLICY_TYPE = 2

        prepended do
          operation_name :backfill_pipeline_execution_policies_config_links
          scope_to ->(relation) { relation.where(type: PIPELINE_EXECUTION_POLICY_TYPE) }
        end

        module CaseSensitivity
          extend ActiveSupport::Concern

          class_methods do
            def iwhere(params)
              criteria = self

              params.each do |column, value|
                column = arel_table[column] unless column.is_a?(Arel::Attribute)

                criteria = criteria.where(value_equal(column, value))
              end

              criteria
            end

            private

            def value_equal(column, value)
              lower_value = lower_value(value)

              lower_column(column).eq(lower_value).to_sql
            end

            def lower_value(value)
              Arel::Nodes::NamedFunction.new('LOWER', [Arel::Nodes.build_quoted(value)])
            end

            def lower_column(column)
              column.lower
            end
          end
        end

        class Route < ::ApplicationRecord
          include CaseSensitivity

          self.table_name = 'routes'
        end

        module Routable
          extend ActiveSupport::Concern
          include CaseSensitivity

          included do
            has_one :route, as: :source
          end

          # removed `follow_redirects` as it is not used in the application code
          def self.find_by_full_path(path, route_scope: nil)
            return unless path.present?

            path = path.to_s

            path_condition = { path: path }

            source_type_condition = { source_type: 'Project' } # changed manually for this migration to not use the scoped Project class name

            route = Route.where(source_type_condition).find_by(path_condition) ||
              Route.where(source_type_condition).iwhere(path_condition).take

            return unless route
            return route.source unless route_scope

            route_scope.find_by(id: route.source_id)
          end

          class_methods do
            # removed `follow_redirects` as it is not used in the application code
            def find_by_full_path(path)
              route_scope = all

              Routable.find_by_full_path(
                path,
                route_scope: route_scope
              )
            end
          end
        end

        class Project < ::ApplicationRecord
          include Routable

          self.table_name = 'projects'

          belongs_to :parent,
            class_name: '::EE::Gitlab::BackgroundMigration::BackfillPipelineExecutionPoliciesConfigLinks::Namespace'
          has_one :route, as: :source,
            class_name: '::EE::Gitlab::BackgroundMigration::BackfillPipelineExecutionPoliciesConfigLinks::Route'
          belongs_to :namespace
        end

        class Namespace < ::ApplicationRecord
          include Routable

          self.table_name = 'namespaces'
          self.inheritance_column = :_type_disabled

          belongs_to :parent,
            class_name: '::EE::Gitlab::BackgroundMigration::BackfillPipelineExecutionPoliciesConfigLinks::Namespace'
        end

        class PipelineExecutionPolicyConfigLink < ::ApplicationRecord
          self.table_name = 'security_pipeline_execution_policy_config_links'

          belongs_to :security_policy,
            class_name: '::EE::Gitlab::BackgroundMigration::BackfillPipelineExecutionPoliciesConfigLinks::SecurityPolicy',
            inverse_of: :security_pipeline_execution_policy_config_link
          belongs_to :project, class_name: '::EE::Gitlab::BackgroundMigration::BackfillPipelineExecutionPoliciesConfigLinks::Project'
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

          has_one :security_pipeline_execution_policy_config_link,
            class_name: '::EE::Gitlab::BackgroundMigration::BackfillPipelineExecutionPoliciesConfigLinks::PipelineExecutionPolicyConfigLink',
            inverse_of: :security_policy

          def pipeline_execution_ci_config
            content&.dig('content', 'include', 0)
          end

          def update_pipeline_execution_policy_config_link!
            return unless type_pipeline_execution_policy?

            # Changed from the application code to avoid recreating existing links
            return if security_pipeline_execution_policy_config_link.present?

            config_project = Project.find_by_full_path(pipeline_execution_ci_config['project'])
            create_security_pipeline_execution_policy_config_link!(project: config_project) if config_project
          end
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            SecurityPolicy.id_in(sub_batch).find_each(&:update_pipeline_execution_policy_config_link!)
          end
        end
      end
      # rubocop:enable Layout/LineLength
    end
  end
end
