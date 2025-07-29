# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module BackfillAnalyzerProjectStatuses
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        class Namespace < ::ApplicationRecord
          self.table_name = 'namespaces'
        end

        class Project < ::ApplicationRecord
          self.table_name = 'projects'
          belongs_to :namespace
        end

        class Pipeline < ::Ci::ApplicationRecord
          self.table_name = 'p_ci_pipelines'
          self.primary_key = :id
          belongs_to :project
          has_many :builds, ->(pipeline) { in_partition(pipeline) }, foreign_key: :commit_id,
            inverse_of: :pipeline, partition_foreign_key: :partition_id,
            class_name: 'EE::Gitlab::BackgroundMigration::BackfillAnalyzerProjectStatuses::Build'
        end

        class BuildMetadata < ::Ci::ApplicationRecord
          self.table_name = 'p_ci_builds_metadata'
          belongs_to :build, ->(metadata) { in_partition(metadata) }, partition_foreign_key: :partition_id,
            class_name: 'EE::Gitlab::BackgroundMigration::BackfillAnalyzerProjectStatuses::Build'
        end

        class Build < ::Ci::ApplicationRecord
          self.table_name = 'p_ci_builds'
          self.primary_key = :id
          # rubocop:disable Database/AvoidInheritanceColumn -- Existing class
          self.inheritance_column = nil
          # rubocop:enable Database/AvoidInheritanceColumn

          serialize :options

          belongs_to :pipeline

          has_one :metadata,
            ->(build) { where(partition_id: build.partition_id) },
            class_name: 'BuildMetadata',
            foreign_key: :build_id,
            partition_foreign_key: :partition_id,
            inverse_of: :build

          scope :with_statuses, ->(statuses) { where(status: statuses) }
          scope :in_pipelines, ->(pipelines) { where(commit_id: pipelines) }
          scope :with_secure_reports_from_config_options, ->(job_types) do
            joins(:metadata).where("#{BuildMetadata.quoted_table_name}.config_options -> 'artifacts' -> 'reports' ?|
              array[:job_types]", job_types: job_types)
          end

          def options
            build_options = read_attribute(:options)
            return build_options if build_options.present?

            metadata_options = metadata&.read_attribute(:config_options)
            metadata_options.presence
          end
        end

        STATUS_ENUM = {
          not_configured: 0,
          success: 1,
          failed: 2
        }.freeze

        STATUS_MAPPING = {
          "success" => :success,
          "failed" => :failed,
          "canceled" => :failed,
          "skipped" => :failed
        }.freeze

        STATUS_PRIORITY = {
          failed: 2,
          success: 1,
          not_configured: 0
        }.freeze

        COMPLETED_STATUSES = %w[success failed].freeze

        ANALYZER_TYPES = {
          sast: 0,
          sast_advanced: 1,
          sast_iac: 2,
          dast: 3,
          dependency_scanning: 4,
          container_scanning: 5,
          secret_detection: 6,
          coverage_fuzzing: 7,
          api_fuzzing: 8,
          cluster_image_scanning: 9
        }.freeze

        prepended do
          operation_name :backfill_analyzer_project_statuses
          feature_category :vulnerability_management
        end

        override :perform

        def perform
          each_sub_batch do |sub_batch|
            projects_info = sub_batch.pluck(:project_id, :traversal_ids, :latest_pipeline_id, :archived)
            process_project_info(projects_info)
          end
        end

        def process_project_info(project_info)
          project_statuses = []

          project_info.each do |project_id, traversal_ids, pipeline_id, archived|
            next unless pipeline_id && traversal_ids && project_id

            builds = fetch_pipeline_builds(pipeline_id)
            next unless builds.present?

            statuses = process_builds(builds, project_id, traversal_ids, archived)
            project_statuses.concat(statuses) if statuses.any?
          end

          upsert_analyzer_statuses(project_statuses) if project_statuses.any?
        end

        def fetch_pipeline_builds(pipeline_id)
          Build.in_pipelines(pipeline_id).with_secure_reports_from_config_options(ANALYZER_TYPES.keys)
               .with_statuses(COMPLETED_STATUSES)
        end

        def process_builds(builds, project_id, traversal_ids, archived)
          analyzer_statuses = {}

          builds.find_each do |build|
            build_analyzer_groups = analyzer_groups_from_build(build)
            next unless build_analyzer_groups.present?

            build_analyzer_groups.each do |analyzer_type|
              status = STATUS_MAPPING[build.status] || :not_configured
              analyzer_type_enum = ANALYZER_TYPES[analyzer_type.to_sym]
              next unless analyzer_type_enum && status

              next unless should_update_status?(analyzer_statuses, analyzer_type_enum, status)

              analyzer_statuses[analyzer_type_enum] = {
                project_id: project_id,
                traversal_ids: traversal_ids,
                analyzer_type: analyzer_type_enum,
                status: status,
                last_call: build.started_at,
                build_id: build.id,
                archived: archived
              }
            end
          end
          analyzer_statuses.values
        end

        def analyzer_groups_from_build(build)
          artifacts = build.options&.dig('artifacts', 'reports')
          return [] unless artifacts.present?

          analyzer_types = artifacts.keys & ANALYZER_TYPES.keys.map(&:to_s)

          # Handle special cases for SAST variants
          if analyzer_types.include?('sast')
            # Check build name for special SAST variants
            if build.name == 'kics-iac-sast'
              analyzer_types.push('sast_iac')
              analyzer_types.delete('sast')
            elsif build.name == 'gitlab-advanced-sast'
              analyzer_types.push('sast_advanced')
            end
          end

          analyzer_types
        end

        def upsert_analyzer_statuses(project_statuses)
          return unless project_statuses.any?

          values_sql = build_values_list(project_statuses)
          sql = build_upsert_sql(values_sql)
          SecApplicationRecord.connection.execute(sql)
        end

        def analyzer_status_columns
          %w[project_id traversal_ids analyzer_type status last_call build_id archived created_at updated_at]
        end

        def build_values_list(project_statuses)
          values_list = project_statuses.map do |status_data|
            [
              status_data[:project_id],
              Arel.sql("ARRAY#{status_data[:traversal_ids]}::bigint[]"),
              status_data[:analyzer_type],
              STATUS_ENUM[status_data[:status]],
              format_last_call(status_data[:last_call]),
              status_data[:build_id],
              status_data[:archived],
              Arel.sql('NOW()'),
              Arel.sql('NOW()')
            ]
          end

          Arel::Nodes::ValuesList.new(values_list).to_sql
        end

        def format_last_call(timestamp)
          if timestamp
            timestamp.utc.strftime('%Y-%m-%d %H:%M:%S.%N').to_s
          else
            Arel.sql('CURRENT_TIMESTAMP')
          end
        end

        def build_upsert_sql(values_sql)
          <<~SQL
            INSERT INTO analyzer_project_statuses
              (#{analyzer_status_columns.join(', ')})
            #{values_sql}
            ON CONFLICT (project_id, analyzer_type) DO NOTHING;
          SQL
        end

        def should_update_status?(analyzer_statuses, analyzer_type_enum, new_status)
          status_priority(new_status) > status_priority(analyzer_statuses[analyzer_type_enum]&.dig(:status))
        end

        def status_priority(status)
          STATUS_PRIORITY[status] || -1
        end
      end
    end
  end
end
