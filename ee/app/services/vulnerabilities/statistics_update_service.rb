# frozen_string_literal: true

module Vulnerabilities
  class StatisticsUpdateService
    def self.update_for(vulnerability)
      new(vulnerability).execute
    end

    def initialize(vulnerability)
      self.vulnerability = vulnerability
    end

    def execute
      return if vulnerability.nil?

      Statistics::UpdateService.update_for(vulnerability)
      NamespaceStatistics::UpdateService.execute(vulnerability_to_diffs)
    end

    private

    attr_accessor :vulnerability

    def vulnerability_to_diffs
      return unless stat_diff&.update_required?

      formatted_traversal_ids = "{#{namespace.traversal_ids.join(', ')}}"

      diff_hash = {
        "namespace_id" => namespace.id,
        "traversal_ids" => formatted_traversal_ids
      }
      diff_hash.merge!(severity_changes)

      [diff_hash]
    end

    def severity_changes
      fill_in_zeros(stat_diff.changes)
    end

    def namespace
      @namespace ||= vulnerability.project.namespace
    end

    def stat_diff
      @stat_diff ||= vulnerability.stat_diff
    end

    def severity_levels
      ::Enums::Vulnerability.severity_levels.keys.map(&:to_s)
    end

    def fill_in_zeros(changes)
      severity_levels.each do |key|
        changes[key] ||= 0
      end

      changes
    end
  end
end
