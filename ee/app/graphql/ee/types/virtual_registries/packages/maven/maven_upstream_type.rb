# frozen_string_literal: true

# rubocop: disable Gitlab/EeOnlyClass -- EE only class with no CE equivalent
module EE
  module Types
    module VirtualRegistries
      module Packages
        module Maven
          class MavenUpstreamType < ::Types::BaseObject
            graphql_name 'MavenUpstream'
            description 'Represents the upstream registries of a Maven virtual registry.'

            authorize :read_virtual_registry

            field :id, GraphQL::Types::ID, null: false,
              description: 'ID of the upstream registry.',
              experiment: { milestone: '18.1' }

            field :url, GraphQL::Types::String, null: false,
              description: 'URL of the upstream registry.',
              experiment: { milestone: '18.1' }

            field :cache_validity_hours, GraphQL::Types::Int, null: false,
              description: 'Time before the cache expires for the upstream registry.',
              experiment: { milestone: '18.1' }

            field :username, GraphQL::Types::String, null: true,
              description: 'Username to sign in to the upstream registry.',
              experiment: { milestone: '18.1' }

            field :password, GraphQL::Types::String, null: true,
              description: 'Password to sign in to the upstream registry.',
              experiment: { milestone: '18.1' }

            field :name, GraphQL::Types::String, null: false,
              description: 'Name of the upstream registry.',
              experiment: { milestone: '18.1' }

            field :description, GraphQL::Types::String, null: true,
              description: 'Description of the upstream registry.',
              experiment: { milestone: '18.1' }

            field :registry_upstreams,
              [EE::Types::VirtualRegistries::Packages::Maven::MavenRegistryUpstreamType],
              null: false,
              description: 'Represents the upstream registry for the upstream ' \
                'which contains the position data.',
              experiment: { milestone: '18.2' }
          end
        end
      end
    end
  end
end
# rubocop: enable Gitlab/EeOnlyClass
