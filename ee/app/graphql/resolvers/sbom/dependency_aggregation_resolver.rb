# frozen_string_literal: true

module Resolvers
  module Sbom
    class DependencyAggregationResolver < DependencyInterfaceResolver
      type Types::Sbom::DependencyAggregationType.connection_type, null: true

      authorize :read_dependency
      authorizes_object!

      argument :project_count_min, GraphQL::Types::Int,
        required: false,
        description: 'Filter dependencies by minimum project count.'

      argument :project_count_max, GraphQL::Types::Int,
        required: false,
        description: 'Filter dependencies by maximum project count.'

      def preloads
        {
          name: [:component],
          version: [:component_version],
          component_version: [:component_version]
        }
      end

      private

      alias_method :group, :object

      def dependencies(params)
        finder = ::Sbom::AggregationsFinder.new(
          group,
          params: mapped_params(params)
        )

        apply_lookahead(finder.execute)
      end
    end
  end
end
