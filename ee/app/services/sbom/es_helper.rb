# frozen_string_literal: true

module Sbom
  module EsHelper
    VULNERABILITY_BATCH_SIZE = 1000

    def sync_elasticsearch(vulnerability_ids)
      return if vulnerability_ids.empty?

      vulnerability_ids.each_slice(VULNERABILITY_BATCH_SIZE) do |vul_ids_batch|
        vulnerability_relation = Vulnerability.id_in(vul_ids_batch)
        ::Vulnerabilities::BulkEsOperationService.new(vulnerability_relation).execute(&:itself)
      end
    end
  end
end
