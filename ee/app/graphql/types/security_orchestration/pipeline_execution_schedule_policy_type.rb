# frozen_string_literal: true

module Types
  module SecurityOrchestration
    # rubocop: disable Graphql/AuthorizeTypes -- authorization
    # this represents a hash, from the orchestration policy configuration
    # the authorization happens for that configuration
    class PipelineExecutionSchedulePolicyType < PipelineExecutionScheduledPolicyAttributesType
      graphql_name 'PipelineExecutionSchedulePolicy'
      description 'Represents the pipeline execution schedule policy'

      implements OrchestrationPolicyType
    end
    # rubocop: enable Graphql/AuthorizeTypes
  end
end
