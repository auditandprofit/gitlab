# frozen_string_literal: true

module Types
  module Namespaces
    class GroupMinimalAccessType < BaseObject
      graphql_name 'GroupMinimalAccess'

      # rubocop:disable Layout/LineLength -- otherwise description is creating unnecessary newlines.
      description 'Limited group data accessible to users without full group read access (e.g. non-members with READ_ADMIN_CICD admin custom role).'
      # rubocop:enable Layout/LineLength

      authorize :read_group_metadata

      implements GroupInterface

      field :avatar_url,
        type: GraphQL::Types::String,
        null: true,
        description: 'Avatar URL of the group.'
      field :full_name, GraphQL::Types::String, null: false,
        description: 'Full name of the group.'
      field :name, GraphQL::Types::String, null: false,
        description: 'Name of the group.'

      def avatar_url
        object.avatar_url(only_path: false)
      end
    end
  end
end
