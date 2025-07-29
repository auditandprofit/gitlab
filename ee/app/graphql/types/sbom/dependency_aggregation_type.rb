# frozen_string_literal: true

module Types
  module Sbom
    class DependencyAggregationType < BaseObject # rubocop:disable Graphql/AuthorizeTypes -- Authorization checks are implemented on the parent object.
      graphql_name 'DependencyAggregation'
      description 'A software dependency aggregation used by a group'

      implements Types::Sbom::DependencyInterface

      field :occurrence_count, GraphQL::Types::Int,
        null: false,
        description: 'Number of occurrences of the dependency across projects.'
    end
  end
end
