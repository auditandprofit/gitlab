# frozen_string_literal: true

module Types
  module Vulnerabilities
    class RepresentationInformationType < BaseObject
      graphql_name 'VulnerabilityRepresentationInformation'
      description 'Represents vulnerability information'

      authorize :read_vulnerability_representation_information

      field :resolved_in_commit_sha, GraphQL::Types::String, null: true,
        description: 'SHA of the commit where the vulnerability was resolved.'
    end
  end
end
