# frozen_string_literal: true

module Types
  module Vulnerabilities
    # rubocop: disable Graphql/AuthorizeTypes -- object is a hash.
    class CvssType < BaseObject
      graphql_name 'CvssType'
      description "Represents a vulnerability's CVSS score."

      include ::Gitlab::Utils::StrongMemoize

      field :vector, ::GraphQL::Types::String,
        null: false, description: 'CVSS vector string.', hash_key: "vector"

      field :vendor, ::GraphQL::Types::String,
        null: false, description: 'Vendor who assigned the CVSS score.', hash_key: "vendor"

      field :version, ::GraphQL::Types::Float,
        null: false, description: 'Version of the CVSS.'

      field :base_score, ::GraphQL::Types::Float,
        null: false, description: 'Base score of the CVSS.'

      field :overall_score, ::GraphQL::Types::Float,
        null: false, description: 'Overall score of the CVSS.'

      field :severity, ::Types::Vulnerabilities::CvssSeverityEnum,
        null: false, description: 'Severity calculated from the overall score.'

      delegate :base_score, :overall_score, :severity, :version, to: :cvss

      private

      def cvss
        ::CvssSuite.new(object['vector'])
      end
      strong_memoize_attr :cvss
    end
  end
  # rubocop: enable Graphql/AuthorizeTypes
end
