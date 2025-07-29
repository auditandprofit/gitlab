# frozen_string_literal: true

module Types
  module Security
    class AnalyzerProjectStatusType < BaseObject
      graphql_name 'AnalyzerProjectStatusType'
      description 'Analyzer status (success/fail) for projects'
      authorize :read_security_inventory

      field :project_id,
        type: GraphQL::Types::Int,
        null: false,
        description: 'Project ID.'

      field :analyzer_type,
        type: AnalyzerTypeEnum,
        null: false,
        description: 'Analyzer type.'

      field :status,
        type: AnalyzerStatusEnum,
        null: false,
        description: 'Analyzer status.'

      field :last_call,
        type: Types::TimeType,
        null: false,
        description: 'Last time analyzer was called.'

      field :build_id,
        type: ::Types::GlobalIDType[::CommitStatus],
        null: true,
        description: 'Build ID.'

      field :updated_at,
        type: GraphQL::Types::ISO8601DateTime,
        null: false,
        description: 'Timestamp of when the status was last updated.'
    end
  end
end
