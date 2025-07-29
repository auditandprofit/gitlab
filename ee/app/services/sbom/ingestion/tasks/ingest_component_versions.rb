# frozen_string_literal: true

module Sbom
  module Ingestion
    module Tasks
      class IngestComponentVersions < Base
        COMPONENT_VERSION_ATTRIBUTES = %i[component_id version].freeze

        self.model = Sbom::ComponentVersion
        self.unique_by = COMPONENT_VERSION_ATTRIBUTES
        self.uses = %i[id component_id version].freeze

        private

        def existing_records
          @existing_records ||= occurrence_maps.map do |occurrence_map|
            Sbom::ComponentVersion.by_component_id_and_version(*occurrence_map.to_h.values_at(:component_id, :version))
          end.reduce(:or)
        end

        def existing_record(map_data)
          existing_records.find do |version|
            COMPONENT_VERSION_ATTRIBUTES.all? do |attribute|
              map_data[attribute] == version[attribute]
            end
          end
        end

        def after_ingest
          each_pair do |occurrence_map, row|
            occurrence_map.component_version_id = row.first
          end
        end

        def attributes
          insertable_maps.filter_map do |occurrence_map|
            map_data = occurrence_map.to_h.slice(*COMPONENT_VERSION_ATTRIBUTES).merge!(organization_id: organization_id)
            existing_record = existing_record(map_data)

            if existing_record.present?
              occurrence_map.component_version_id = existing_record.id
              next
            end

            map_data
          end
        end

        def insertable_maps
          super.filter(&:version_present?)
        end
      end
    end
  end
end
