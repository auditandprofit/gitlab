# frozen_string_literal: true

# rubocop: disable Gitlab/EeOnlyClass -- EE only class with no CE equivalent
module EE
  module Types
    module VirtualRegistries
      module Packages
        module Maven
          class MavenVirtualRegistryType < ::Types::BaseObject
            graphql_name 'MavenVirtualRegistry'
            description 'Represents a Maven virtual registry'

            authorize :read_virtual_registry

            alias_method :registry, :object

            field :id, GraphQL::Types::ID, null: false,
              description: 'ID of the virtual registry.'

            field :name, GraphQL::Types::String, null: false,
              description: 'Name of the virtual registry.'

            field :description, GraphQL::Types::String, null: true,
              description: 'Description of the virtual registry.'

            field :upstreams,
              [EE::Types::VirtualRegistries::Packages::Maven::MavenUpstreamType],
              null: true,
              description: 'List of upstream registries for the Maven virtual registry.',
              experiment: { milestone: '18.1' }

            def upstreams
              ::VirtualRegistries::Packages::Maven::Upstream.eager_load_registry_upstream(registry: registry)
            end
          end
        end
      end
    end
  end
end
# rubocop: enable Gitlab/EeOnlyClass
