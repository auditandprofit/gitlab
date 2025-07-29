# frozen_string_literal: true

module Vulnerabilities
  class PartialScan < SecApplicationRecord
    self.table_name = 'vulnerability_partial_scans'

    enum :mode, {
      differential: 1
    }

    enum :scan_type, Security::Scan.scan_types

    belongs_to :project
    belongs_to :scan, class_name: 'Security::Scan'
    belongs_to :pipeline, class_name: 'Ci::Pipeline'

    validates :scan, presence: true
    validates :mode, presence: true
    validates :project, presence: true

    before_validation :set_attributes_from_scan

    def set_attributes_from_scan
      # Since this happens before validation it is possible that there is no scan
      return unless scan

      self.project_id ||= scan.project_id
      self.pipeline_id ||= scan.pipeline_id
      self.scan_type ||= scan.scan_type
    end
  end
end
