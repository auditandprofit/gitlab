# frozen_string_literal: true

module Sbom
  module Ingestion
    class DeleteNotPresentOccurrencesService
      include Sbom::EsHelper

      DELETE_BATCH_SIZE = 100

      def self.execute(...)
        new(...).execute
      end

      def initialize(pipeline, ingested_occurrence_ids)
        @pipeline = pipeline
        @ingested_occurrence_ids = ingested_occurrence_ids
      end

      def execute
        return if has_failed_sbom_jobs?

        vulnerability_ids = collect_vulnerability_ids_and_delete_occurrences
        sync_elasticsearch(vulnerability_ids)
      end

      private

      attr_reader :pipeline, :ingested_occurrence_ids

      delegate :project, to: :pipeline, private: true

      def has_failed_sbom_jobs?
        # rubocop:disable CodeReuse/ActiveRecord -- This logic is specific to this service
        pipeline.builds.preload(:metadata).failed.find_each(batch_size: 100).any? { |b| sbom_build?(b) }
        # rubocop:enable CodeReuse/ActiveRecord
      end

      def sbom_build?(build)
        build.options.dig(:artifacts, :reports, :cyclonedx).present?
      end

      def not_present_occurrences
        project.sbom_occurrences.filter_by_source_types(default_source_type_filters).id_not_in(ingested_occurrence_ids)
      end

      def default_source_type_filters
        ::Sbom::Source::DEFAULT_SOURCES.keys + [nil]
      end

      def collect_vulnerability_ids_and_delete_occurrences
        vulnerability_ids = []

        not_present_occurrences.each_batch(of: DELETE_BATCH_SIZE) do |occurrences, _|
          vulnerability_ids += extract_vulnerability_ids(occurrences)
          occurrences.delete_all
        end

        vulnerability_ids.uniq.compact
      end

      def extract_vulnerability_ids(occurrences)
        Sbom::OccurrencesVulnerability
          .for_occurrence_ids(occurrences.select(:id))
          .map(&:vulnerability_id)
      end
    end
  end
end
