# frozen_string_literal: true

module Dependencies
  module ExportSerializers
    module Sbom
      class PipelineService
        include ::Sbom::Exporters::WriteBlob

        SchemaValidationError = Class.new(StandardError)

        def initialize(dependency_list_export, _sbom_occurrences)
          @dependency_list_export = dependency_list_export

          @pipeline = dependency_list_export.pipeline
          @project = pipeline.project
        end

        def generate(&block)
          write_json_blob(sbom_data, &block)
        end

        private

        def sbom_data
          entity = serializer_service.execute
          return entity if serializer_service.valid?

          raise SchemaValidationError, "Invalid CycloneDX report: #{serializer_service.errors.join(', ')}"
        end

        def serializer_service
          @service ||= ::Sbom::ExportSerializers::JsonService.new(merged_report)
        end

        def merged_report
          ::Sbom::MergeReportsService.new(pipeline.sbom_reports.reports).execute
        end

        attr_reader :dependency_list_export, :scanner, :pipeline, :project
      end
    end
  end
end
