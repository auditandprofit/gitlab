# frozen_string_literal: true

module Gitlab
  module Ci
    module Pipeline
      class JobsInjector
        include Gitlab::Utils::StrongMemoize

        DuplicateJobNameError = Class.new(StandardError)

        def initialize(pipeline:, declared_stages:, on_conflict:)
          @pipeline = pipeline
          @project = pipeline.project
          @declared_stages = declared_stages
          @rename_on_conflict = on_conflict

          @pipeline_jobs_by_name = pipeline.stages.flat_map(&:statuses).index_by(&:name)
          @pipeline_stages_by_name = pipeline.stages.index_by(&:name)
          @job_renames = {} # Keep track of all job renaming performed due to conflicts
          @jobs_with_needs = [] # Keep track of all jobs with `needs` that may require update due to the renaming
        end

        def inject_jobs(jobs:, stage:)
          target_stage = ensure_stage_exists(stage)
          return unless target_stage

          jobs.each do |job|
            # We need to assign the new stage_idx for the jobs
            # because the source stages could have had different positions
            job.assign_attributes(pipeline: pipeline, stage_idx: target_stage.position)
            add_suffix(job: job)
            add_job(stage: target_stage, job: job)

            yield(job) if block_given?
          end

          update_needs_references!
        end

        private

        attr_reader :pipeline, :project, :declared_stages, :pipeline_stages_by_name, :pipeline_jobs_by_name

        def ensure_stage_exists(stage)
          existing_stage = pipeline_stages_by_name[stage.name]
          return existing_stage if existing_stage.present?
          return unless stage_declared_in_project_config?(stage)

          insert_stage_into_pipeline(stage).tap do |pipeline_stage|
            pipeline_stages_by_name[pipeline_stage.name] = pipeline_stage
          end
        end

        def declared_stages_positions
          declared_stages.each_with_index.to_h
        end
        strong_memoize_attr :declared_stages_positions

        def stage_declared_in_project_config?(stage)
          declared_stages_positions.key?(stage.name)
        end

        def insert_stage_into_pipeline(source_stage)
          source_stage.dup.tap do |target_stage|
            position = declared_stages_positions[target_stage.name]
            target_stage.assign_attributes(pipeline: pipeline, position: position)
            pipeline.stages << target_stage
          end
        end

        # Add suffix based on `rename_on_conflict` lambda. If it returns `nil`, no renaming is performed
        def add_suffix(job:)
          return unless pipeline_jobs_by_name.key?(job.name)

          original_name = job.name
          new_name = @rename_on_conflict&.call(job.name)
          return unless new_name

          job.name = new_name
          @job_renames[original_name] = new_name
        end

        def add_job(stage:, job:)
          raise DuplicateJobNameError, "job names must be unique (#{job.name})" if pipeline_jobs_by_name.key?(job.name)

          stage.statuses << job
          pipeline_jobs_by_name[job.name] = job
          @jobs_with_needs << job if job.needs.present?
        end

        def update_needs_references!
          return if @job_renames.blank? || @jobs_with_needs.blank?

          @jobs_with_needs.flat_map(&:needs).each do |need|
            need.name = @job_renames.fetch(need.name, need.name)
          end
        end
      end
    end
  end
end
