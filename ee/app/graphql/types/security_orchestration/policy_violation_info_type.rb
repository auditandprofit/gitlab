# frozen_string_literal: true

module Types
  module SecurityOrchestration
    class PolicyViolationInfoType < BaseObject # rubocop:disable Graphql/AuthorizeTypes -- Authorized via resolver
      graphql_name 'PolicyViolationInfo'
      description 'Represents generic policy violation information.'

      include ::Gitlab::Utils::StrongMemoize

      field :name,
        type: GraphQL::Types::String,
        null: false,
        description: 'Represents the name of the violated policy.'

      field :report_type,
        type: ApprovalReportTypeEnum,
        null: false,
        description: 'Represents the report type.'

      field :status,
        type: PolicyViolationStatusEnum,
        description: 'Represents the status of the violated policy.'
    end
  end
end
