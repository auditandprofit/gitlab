# frozen_string_literal: true

module Sbom
  module Ingestion
    module Tasks
      class IngestOccurrencesVulnerabilities < Base
        self.model = Sbom::OccurrencesVulnerability
        self.unique_by = %i[sbom_occurrence_id vulnerability_id].freeze
        self.uses = :vulnerability_id

        private

        def attributes
          insertable_maps.flat_map do |occurrence_map|
            occurrence_map.vulnerability_ids.map do |vulnerability_id|
              {
                sbom_occurrence_id: occurrence_map.occurrence_id,
                vulnerability_id: vulnerability_id
              }
            end
          end
        end

        def after_ingest
          return unless return_data.present?

          vulnerabilities_relation = Vulnerability.id_in(return_data.flatten)

          sync_elasticsearch(vulnerabilities_relation) if vulnerabilities_relation.present?
        end

        def sync_elasticsearch(vulnerabilities)
          ::Vulnerabilities::BulkEsOperationService.new(vulnerabilities).execute(&:itself)
        end
      end
    end
  end
end
