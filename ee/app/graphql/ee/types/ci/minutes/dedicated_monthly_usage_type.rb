# frozen_string_literal: true

# rubocop:disable Gitlab/EeOnlyClass -- TODO: move to ee/app/graphql/types/ci/minutes/dedicated_monthly_usage_type.rb
module EE
  module Types
    module Ci
      module Minutes
        class DedicatedMonthlyUsageType < ::Types::BaseObject
          graphql_name 'CiDedicatedHostedRunnerUsage'
          description 'Compute usage data for hosted runners on GitLab Dedicated.'

          authorize :read_dedicated_hosted_runner_usage

          field :billing_month, GraphQL::Types::String, null: false,
            method: :billing_month_formatted,
            description: 'Month of the usage data.'

          field :billing_month_iso8601, GraphQL::Types::ISO8601Date, null: false, # rubocop:disable GraphQL/ExtractType -- we need it separate
            description: 'Timestamp of the billing month in ISO 8601 format.'

          field :compute_minutes, GraphQL::Types::Int, null: false,
            description: 'Total compute minutes used across all namespaces.'

          field :duration_seconds, GraphQL::Types::Int, null: false,
            description: 'Total duration in seconds of runner usage.'

          field :root_namespace, ::Types::Ci::Minutes::NamespaceUnionType, null: true,
            description: 'Namespace associated with the usage data. Null for instance aggregate data.'

          def root_namespace
            return unless object.root_namespace_id.present?

            existing_namespace = object.root_namespace
            return existing_namespace if existing_namespace.present?

            ::Types::Ci::Minutes::DeletedNamespaceType::DeletedNamespace.new(
              object.root_namespace_id
            )
          end
        end
      end
    end
  end
end
# rubocop:enable Gitlab/EeOnlyClass
