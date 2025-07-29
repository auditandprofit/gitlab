# frozen_string_literal: true

module Sbom
  module Ingestion
    class IngestReportService
      BATCH_SIZE = 10
      CACHE_EXPIRATION_TIME = 24.hours

      def self.execute(pipeline, sbom_report)
        new(pipeline, sbom_report).execute
      end

      def initialize(pipeline, sbom_report)
        @pipeline = pipeline
        @sbom_report = sbom_report
      end

      def execute
        results = occurrence_map_collection.each_slice(BATCH_SIZE).map do |slice|
          ingest_slice(slice)
        end
        build_dependency_graph
        results
      end

      private

      attr_reader :pipeline, :sbom_report

      delegate :project, to: :pipeline, private: true

      def occurrence_map_collection
        @occurrence_map_collection ||= OccurrenceMapCollection.new(sbom_report)
      end

      def ingest_slice(slice)
        IngestReportSliceService.execute(pipeline, slice)
      end

      def build_dependency_graph
        return unless Feature.enabled?(:dependency_paths, project.group)

        if graph_needs_update?
          log_info("Building dependency graph")

          record_graph_updated

          ::Sbom::BuildDependencyGraphWorker.perform_async(project.id)
        else
          log_info("Graph already built")
        end
      end

      def graph_needs_update?
        # The cache key contains a hash of the report contents. If the cache key is present
        # in the store, we skip building the dependency graph since it has already been built
        # (or is currently being built by another process)
        Rails.cache.read(cache_key).nil?
      end

      def record_graph_updated
        # Write cache key before processing the graph so that we stop other graph builds
        # from starting in parallel before this one completes.
        Rails.cache.write(cache_key, { pipeline_id: pipeline.id }, expires_in: CACHE_EXPIRATION_TIME)
      end

      def log_info(message)
        ::Gitlab::AppLogger.info(
          message: message,
          project: project.name,
          project_id: project.id,
          namespace: project.namespace.name,
          namespace_id: project.namespace.id,
          cache_key: cache_key.to_s
        )
      end

      def cache_key
        @cache_key ||= Sbom::Ingestion::DependencyGraphCacheKey.new(project, sbom_report).key
      end
    end
  end
end
