# frozen_string_literal: true

module Vulnerabilities
  class BulkEsOperationService
    def initialize(relation)
      @relation = relation
    end

    def execute
      return unless block_given?

      return yield relation unless ::Search::Elastic::VulnerabilityIndexingHelper.vulnerability_indexing_allowed?

      vulnerabilities = relation.dup

      vulnerabilities.load
      associations = nil
      if vulnerabilities.first.is_a?(Vulnerability)
        associations = [:project, :group]
      elsif vulnerabilities.first.is_a?(Vulnerabilities::Read)
        associations = [vulnerability: [:project, :group]]
      end

      ActiveRecord::Associations::Preloader.new(
        records: vulnerabilities,
        associations: associations
      ).call
      eligible_vulnerabilities = vulnerabilities.select(&:maintaining_elasticsearch?)

      yield relation

      ::Elastic::ProcessBookkeepingService.track!(*eligible_vulnerabilities)
    end

    private

    attr_reader :relation
  end
end
