# frozen_string_literal: true

module Types
  module Vulnerabilities
    # rubocop: disable Graphql/AuthorizeTypes -- data is instance-wide and doesn't have a project association.
    class CveEnrichmentType < BaseObject
      graphql_name 'CveEnrichmentType'
      description "Represents a CVE's Enrichment (EPSS score)."

      field :cve, ::GraphQL::Types::String,
        null: false, description: 'CVE identifier of relevant vulnerability.'

      field :epss_score, ::GraphQL::Types::Float,
        null: false, description: 'EPSS score for the CVE.'

      field :is_known_exploit, ::GraphQL::Types::Boolean,
        null: false, description: 'Whether the CVE appears in the CISA KEV catalog.'
    end
  end
  # rubocop: enable Graphql/AuthorizeTypes
end
