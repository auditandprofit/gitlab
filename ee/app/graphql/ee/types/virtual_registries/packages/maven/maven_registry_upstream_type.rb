# frozen_string_literal: true

# rubocop: disable Gitlab/EeOnlyClass -- EE only class with no CE equivalent
module EE
  module Types
    module VirtualRegistries
      module Packages
        module Maven
          class MavenRegistryUpstreamType < ::Types::BaseObject
            graphql_name 'MavenRegistryUpstream'
            description 'Represents the upstream registries of a Maven virtual registry.'

            field :id, GraphQL::Types::ID, null: false,
              description: 'ID of the registry upstream.',
              experiment: { milestone: '18.2' }

            field :position, GraphQL::Types::Int, null: false,
              description: 'Position of the upstream registry in an ordered list.',
              experiment: { milestone: '18.2' }
          end
        end
      end
    end
  end
end
# rubocop: enable Gitlab/EeOnlyClass -- EE only class with no CE equivalent
