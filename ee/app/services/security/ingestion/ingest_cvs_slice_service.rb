# frozen_string_literal: true

module Security
  module Ingestion
    class IngestCvsSliceService < IngestSliceBaseService
      SEC_DB_TASKS = %i[
        IngestCvsSecurityScanners
        IngestIdentifiers
        IngestFindings
        IngestVulnerabilities
        IncreaseCountersTask
        AttachFindingsToVulnerabilities
        IngestFindingIdentifiers
        IngestFindingLinks
        IngestFindingSignatures
        IngestFindingEvidence
        IngestVulnerabilityFlags
        IngestVulnerabilityReads
        IngestVulnerabilityStatistics
        IngestVulnerabilityNamespaceStatistics
        HooksExecution
      ].freeze

      MAIN_DB_TASKS = %i[
        MarkCvsProjectsAsVulnerable
      ].freeze

      def self.execute(finding_maps)
        super(nil, finding_maps)
      end
    end
  end
end
