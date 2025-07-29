# frozen_string_literal: true

module Mutations
  module Users
    module Abuse
      module NamespaceBans
        class Destroy < BaseMutation
          graphql_name 'NamespaceBanDestroy'

          authorize :owner_access

          argument :id, Types::GlobalIDType[::Namespaces::NamespaceBan],
            required: true,
            description: 'Global ID of the namespace ban to remove.'

          field :namespace_ban,
            Types::Namespaces::NamespaceBanType,
            null: true,
            description: 'Namespace Ban.'

          def resolve(id:)
            namespace_ban = authorized_find!(id: id)

            response = ::Users::Abuse::NamespaceBans::DestroyService.new(
              namespace_ban,
              current_user
            ).execute

            {
              namespace_ban: response.payload[:namespace_ban],
              errors: response.errors
            }
          end
        end
      end
    end
  end
end
