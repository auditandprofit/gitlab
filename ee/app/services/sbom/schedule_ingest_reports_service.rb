# frozen_string_literal: true

module Sbom
  class ScheduleIngestReportsService
    include Gitlab::Utils::StrongMemoize

    def initialize(pipeline)
      @pipeline = pipeline
    end

    def execute
      return unless pipeline.project.namespace.ingest_sbom_reports_available?
      return unless pipeline.default_branch?
      return unless all_pipelines_complete? && any_pipeline_has_sbom_reports?

      ::Sbom::IngestReportsWorker.perform_async(root_pipeline.id)
    end

    private

    attr_reader :pipeline

    def all_pipelines_complete?
      root_pipeline.self_and_project_descendants.all?(&:complete_or_manual?)
    end

    def any_pipeline_has_sbom_reports?
      root_pipeline.builds_in_self_and_project_descendants
        .with_artifacts(::Ci::JobArtifact.of_report_type(:sbom)).any?
    end

    def root_pipeline
      @root_pipeline ||= pipeline.root_ancestor
    end
  end
end
