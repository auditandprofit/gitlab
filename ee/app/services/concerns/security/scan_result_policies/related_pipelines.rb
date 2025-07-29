# frozen_string_literal: true

module Security
  module ScanResultPolicies
    module RelatedPipelines
      include Gitlab::Utils::StrongMemoize

      def related_pipeline_ids(pipeline)
        strong_memoize_with(:related_pipeline_ids, pipeline) do
          break [] unless pipeline

          Security::RelatedPipelinesFinder.new(pipeline, {
            sources: related_pipeline_sources
          }).execute
        end
      end

      def related_pipelines(pipeline)
        strong_memoize_with(:related_pipelines, pipeline) do
          break Ci::Pipeline.none unless pipeline

          pipeline.project.all_pipelines.id_in(related_pipeline_ids(pipeline))
        end
      end

      def related_target_pipeline_ids_for_merge_request(merge_request, report_type)
        target_pipeline = target_pipeline_for_merge_request(merge_request, report_type)
        return [] unless target_pipeline

        Security::RelatedPipelinesFinder.new(target_pipeline, {
          sources: related_pipeline_sources,
          ref: merge_request.target_branch
        }).execute
      end

      def related_pipeline_sources
        Enums::Ci::Pipeline.ci_and_security_orchestration_sources.values
      end

      def target_pipeline_for_merge_request(merge_request, report_type)
        target_pipeline = if report_type == :scan_finding
                            merge_request.latest_scan_finding_comparison_pipeline
                          elsif report_type == :license_scanning
                            merge_request.latest_comparison_pipeline_with_sbom_reports
                          end

        target_pipeline || merge_request.latest_pipeline_for_target_branch
      end
    end
  end
end
