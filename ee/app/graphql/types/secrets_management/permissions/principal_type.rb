# frozen_string_literal: true

module Types
  module SecretsManagement
    module Permissions
      class PrincipalType < BaseObject # rubocop:disable Graphql/AuthorizeTypes -- This is not necessary because the superclass declares the authorization
        graphql_name 'Principal'
        description 'Representation of who is provided access to. For eg: User/Role/MemberRole/Group.'

        field :id, GraphQL::Types::ID,
          null: false,
          description: 'ID of the principal (User, MemberRole, Role, Group).'

        field :type, GraphQL::Types::String,
          null: false,
          description: 'Name of the principal (User, MemberRole, Role, Group).'

        def id
          object[:id] || object['id']
        end

        def type
          object[:type] || object['type']
        end
      end
    end
  end
end
