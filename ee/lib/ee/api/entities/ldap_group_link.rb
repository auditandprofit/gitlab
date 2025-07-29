# frozen_string_literal: true

module EE
  module API
    module Entities
      class LdapGroupLink < Grape::Entity
        expose :cn, documentation: { type: 'string', example: 'ldap-group-1' }
        expose :group_access, documentation: { type: 'integer', example: 10 }
        expose :provider, documentation: { type: 'string', example: 'ldapmain' }
        expose :filter, documentation: { type: 'string', example: 'id >= 500' }, if: ->(_, _) do
          License.feature_available?(:ldap_group_sync_filter)
        end
        expose :member_role_id, documentation: { type: 'integer', example: 12 }, if: ->(ldap_group_link, _) do
          ldap_group_link.group.custom_roles_enabled?
        end
      end
    end
  end
end
