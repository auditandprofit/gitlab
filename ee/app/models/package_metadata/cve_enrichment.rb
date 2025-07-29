# frozen_string_literal: true

module PackageMetadata
  class CveEnrichment < ApplicationRecord
    include BulkInsertSafe

    self.table_name = 'pm_cve_enrichment'

    # The 15 (total 24) character limit is arbitrary. CVE IDs are not limited
    # but we do not expect them to exceed this limit.
    # See https://cve.mitre.org/cve/identifiers/syntaxchange.html
    CVE_REGEX = /\ACVE-\d{4}-\d{4,15}\z/

    validates :cve, presence: true, format: { with: CVE_REGEX }
    validates :epss_score, presence: true
    validates :is_known_exploit, inclusion: { in: [true, false] }

    scope :by_cves, ->(cves) { where(cve: cves) }
  end
end
