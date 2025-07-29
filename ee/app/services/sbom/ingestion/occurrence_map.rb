# frozen_string_literal: true

module Sbom
  module Ingestion
    class OccurrenceMap
      include Gitlab::Utils::StrongMemoize

      attr_reader :report_component, :report_source
      attr_accessor :component_id, :component_version_id, :source_id, :occurrence_id, :source_package_id, :uuid,
        :vulnerability_ids

      def initialize(report_component, report_source)
        @report_component = report_component
        @report_source = report_source
        @vulnerability_ids = []
      end

      def to_h
        {
          component_id: component_id,
          component_version_id: component_version_id,
          component_type: report_component.component_type,
          name: report_component.name,
          purl_type: purl_type,
          source_id: source_id, source_type: report_source&.source_type,
          source: report_source&.data,
          source_package_id: source_package_id,
          source_package_name: report_component.source_package_name,
          uuid: uuid,
          version: version
        }
      end

      def version_present?
        version.present?
      end

      def purl_type
        report_component.purl&.type
      end

      def packager
        report_component&.properties&.packager || report_source&.packager
      end

      def input_file_path
        return image_ref if container_scanning_component? && image_data_present?

        report_source&.input_file_path
      end

      delegate :image_name, :image_tag, to: :report_source, allow_nil: true
      delegate :name, :version, :source_package_name, :ancestors, :reachability, to: :report_component

      private

      def image_data_present?
        image_name.present? && image_tag.present?
      end

      def container_scanning_component?
        report_component.properties&.source_type&.to_sym == :trivy
      end

      def image_ref
        "container-image:#{image_name}:#{image_tag}"
      end
    end
  end
end
