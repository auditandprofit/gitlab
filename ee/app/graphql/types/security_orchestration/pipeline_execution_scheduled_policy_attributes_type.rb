# frozen_string_literal: true

module Types
  module SecurityOrchestration
    # rubocop: disable Graphql/AuthorizeTypes -- Authorization handled in the resolver
    # this represents a hash, from the orchestration policy configuration
    # the authorization happens for that configuration
    class PipelineExecutionScheduledPolicyAttributesType < PipelineExecutionPolicyAttributesType
      graphql_name 'PipelineExecutionScheduledPolicyAttributesType'
      description 'Represents policy fields related to the pipeline execution scheduled policy.'
    end
    # rubocop: enable Graphql/AuthorizeTypes
  end
end
