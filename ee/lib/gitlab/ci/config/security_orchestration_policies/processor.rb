# frozen_string_literal: true

module Gitlab
  module Ci
    class Config
      module SecurityOrchestrationPolicies
        class Processor
          include Gitlab::Utils::StrongMemoize
          include ::Gitlab::InternalEventsTracking

          DEFAULT_ON_DEMAND_STAGE = 'dast'
          DEFAULT_SECURITY_JOB_STAGE = 'test'

          DEFAULT_BUILD_STAGE = 'build'
          DEFAULT_SCAN_POLICY_STAGE = 'scan-policies'
          DEFAULT_STAGES = Gitlab::Ci::Config::Entry::Stages.default

          def initialize(config, context, ref, pipeline_policy_context)
            @config = config.deep_dup
            @context = context
            @project = context.project
            @ref = ref
            @pipeline_policy_context = pipeline_policy_context
            @start = Time.current
          end

          def perform
            return @config unless scan_execution_policy_context&.has_scan_execution_policies?

            @config[:workflow] = { rules: [{ when: 'always' }] } if @config.empty?

            merged_config = @config.deep_merge(merged_security_policy_config)
            merged_config[:stages] = cleanup_stages(merged_config[:stages])
            merged_config.delete(:stages) if merged_config[:stages].blank?

            track_internal_events_for_enforced_scans
            observe_processing_duration(Time.current - @start)

            merged_config
          end

          private

          attr_reader :project, :ref, :context, :pipeline_policy_context

          delegate :active_scan_execution_actions, to: :scan_execution_policy_context

          def scan_execution_policy_context
            pipeline_policy_context&.scan_execution_context(ref)
          end

          def cleanup_stages(stages)
            stages.uniq!

            return if stages == DEFAULT_STAGES

            stages
          end

          def merged_security_policy_config
            @merged_security_policy_config ||= merge_policies_with_stages(@config)
          end

          def prepare_on_demand_scans_template
            scan_templates[:on_demand]
          end

          def prepare_pipeline_scans_template
            scan_templates[:pipeline_scan]
          end

          def scan_templates
            @scan_templates ||= ::Security::SecurityOrchestrationPolicies::ScanPipelineService
              .new(context)
              .execute(active_scan_execution_actions)
          end

          ## Add `dast` to the end of stages if `dast` is not in stages already
          ## For other scan types, add `scan-policies` stage after `build` stage if `test` stage is not defined
          def merge_policies_with_stages(config)
            merged_config = config
            defined_stages = config[:stages].presence || DEFAULT_STAGES.clone

            merge_on_demand_scan_template(merged_config, defined_stages)
            merge_pipeline_scan_template(merged_config, defined_stages)

            merged_config[:stages] = defined_stages + merged_config.fetch(:stages, [])

            merged_config
          end

          def merge_on_demand_scan_template(merged_config, defined_stages)
            on_demand_scan_template = prepare_on_demand_scans_template
            on_demand_scan_job_names = job_names(on_demand_scan_template.keys)

            if on_demand_scan_template.present?
              insert_stage_before_or_append(defined_stages, DEFAULT_ON_DEMAND_STAGE, ['.post'])
              merged_config.except!(*on_demand_scan_job_names).deep_merge!(on_demand_scan_template)
              scan_execution_policy_context.collect_injected_job_names(on_demand_scan_job_names)
            end
          end

          def merge_pipeline_scan_template(merged_config, defined_stages)
            pipeline_scan_template = prepare_pipeline_scans_template
            pipeline_scan_job_names = job_names(prepare_pipeline_scans_template.keys)

            if pipeline_scan_template.present?
              unless defined_stages.include?(DEFAULT_SECURITY_JOB_STAGE)
                insert_stage_after_or_prepend(defined_stages, DEFAULT_SCAN_POLICY_STAGE, ['.pre', DEFAULT_BUILD_STAGE])
                pipeline_scan_template = pipeline_scan_template.transform_values do |job_config|
                  job_config.merge(stage: DEFAULT_SCAN_POLICY_STAGE)
                end
              end

              merged_config.except!(*pipeline_scan_job_names).deep_merge!(pipeline_scan_template)

              scan_execution_policy_context.collect_injected_job_names(pipeline_scan_job_names)
            end
          end

          def job_names(keys)
            keys - %i[variables]
          end

          def insert_stage_after_or_prepend(stages, insert_stage_name, after_stages)
            stage_index = after_stages.filter_map { |stage| stages.index(stage) }.max

            if stage_index.nil?
              stages.unshift(insert_stage_name)
            else
              stages.insert(stage_index + 1, insert_stage_name)
            end
          end

          def insert_stage_before_or_append(stages, insert_stage_name, before_stages)
            stage_index = before_stages.filter_map { |stage| stages.index(stage) }.min

            if stage_index.nil?
              stages << insert_stage_name
            else
              stages.insert(stage_index, insert_stage_name)
            end
          end

          def track_internal_events_for_enforced_scans
            active_scan_execution_actions.each do |action|
              next unless action[:scan]

              track_internal_event(
                'enforce_scan_execution_policy_in_project',
                project: project,
                additional_properties: {
                  label: action[:scan]
                }
              )
            end
          end

          def observe_processing_duration(duration)
            ::Gitlab::Ci::Pipeline::Metrics
              .pipeline_security_orchestration_policy_processing_duration_histogram
              .observe({}, duration.seconds)
          end
        end
      end
    end
  end
end
