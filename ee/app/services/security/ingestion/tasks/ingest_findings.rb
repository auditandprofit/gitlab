# frozen_string_literal: true

module Security
  module Ingestion
    module Tasks
      class IngestFindings < AbstractTask
        include Gitlab::Ingestion::BulkInsertableTask

        self.model = Vulnerabilities::Finding
        self.unique_by = :uuid
        self.uses = %i[id vulnerability_id].freeze

        private

        def after_ingest
          return_data.each_with_index do |(finding_id, vulnerability_id), index|
            finding_map = finding_maps[index]

            finding_map.finding_id = finding_id
            finding_map.vulnerability_id = vulnerability_id
          end
        end

        def attributes
          finding_maps
            .map(&:to_hash)
            .map { |attrs| truncate_columns(attrs) }
        end

        def truncate_columns(attrs)
          Vulnerabilities::Finding::COLUMN_LENGTH_LIMITS.each do |attr_name, limit|
            attrs[attr_name] = attrs[attr_name]&.truncate(limit)
          end
          attrs
        end
      end
    end
  end
end
