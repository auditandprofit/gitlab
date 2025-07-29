# frozen_string_literal: true

module Vulnerabilities
  class FindingTokenStatusPolicy < BasePolicy
    delegate { @subject.finding.vulnerability }

    condition(:validity_checks_ff) { ::Feature.enabled?(:validity_checks, @subject.project) }
    condition(:read_vulnerability) { can?(:read_vulnerability, @subject.project) }

    rule { validity_checks_ff & read_vulnerability }.policy do
      enable :read_finding_token_status
    end
  end
end
