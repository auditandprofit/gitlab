# frozen_string_literal: true

module Resolvers
  module Sbom
    class DependenciesResolver < DependencyInterfaceResolver
      type Types::Sbom::DependencyType.connection_type, null: true

      private

      def dependencies(params)
        result = ::Sbom::DependenciesFinder.new(object, params: mapped_params(params)).execute

        result = result.with_version if params[:component_versions].present? || params[:not_component_versions].present?

        apply_lookahead(result)
      end
    end
  end
end
