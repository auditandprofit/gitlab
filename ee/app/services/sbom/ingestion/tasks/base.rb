# frozen_string_literal: true

module Sbom
  module Ingestion
    module Tasks
      class Base
        include Gitlab::Utils::StrongMemoize
        include Gitlab::Ingestion::BulkInsertableTask

        def self.execute(pipeline, occurrence_maps)
          new(pipeline, occurrence_maps).execute
        end

        def initialize(pipeline, occurrence_maps)
          @pipeline = pipeline
          @occurrence_maps = occurrence_maps
        end

        private

        attr_reader :pipeline, :occurrence_maps

        delegate :project, to: :pipeline, private: true

        def organization_id
          project.namespace.organization_id
        end

        def insertable_maps
          occurrence_maps
        end

        def each_pair
          validate_unique_by!

          return_data.each do |row|
            occurrence_maps_for_row(row).each { |map| yield map, row }
          end
        end

        def occurrence_maps_for_row(row)
          indexed_occurrence_maps[grouping_key_for_row(row)]
        end

        def indexed_occurrence_maps
          insertable_maps.group_by { |map| grouping_key_for_map(map) }
        end
        strong_memoize_attr :indexed_occurrence_maps

        def grouping_key_for_map(occurrence_map)
          occurrence_map.to_h.values_at(*unique_by)
        end

        def unique_attr_indices
          unique_by.map { |attr| uses.find_index(attr) }
        end
        strong_memoize_attr :unique_attr_indices

        def grouping_key_for_row(row)
          unique_attr_indices.map { |index| row[index] }
        end

        def validate_unique_by!
          raise ArgumentError, '#each_pair can only be used with unique_by attributes' if unique_by.blank?

          return if unique_by.all? { |attr| uses.include?(attr) }

          raise ArgumentError, 'All unique_by attributes must be included in returned columns'
        end
      end
    end
  end
end
