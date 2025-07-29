# frozen_string_literal: true

module Types
  module Sbom
    class DependencyType < BaseObject
      graphql_name 'Dependency'
      description 'A software dependency used by a project'

      implements Types::Sbom::DependencyInterface

      authorize :read_dependency
    end
  end
end
