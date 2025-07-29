# frozen_string_literal: true

module Types
  module SecurityOrchestration
    class PolicyViolationErrorTypeEnum < BaseEnum
      graphql_name 'PolicyViolationErrorType'

      value 'SCAN_REMOVED',
        value: 'SCAN_REMOVED',
        description: 'Represents mismatch between the scans of the source and target pipelines.'

      value 'ARTIFACTS_MISSING',
        value: 'ARTIFACTS_MISSING',
        description: 'Represents error which occurs when pipeline is misconfigured and does not include ' \
                     'necessary artifacts to evaluate a policy.'

      value 'UNKNOWN',
        value: 'UNKNOWN',
        description: 'Represents unknown error.'
    end
  end
end
