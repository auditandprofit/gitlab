# frozen_string_literal: true

module EE
  module API
    module Entities
      class SamlGroupLink < Grape::Entity
        expose :saml_group_name, as: :name, documentation: { type: 'string', example: 'saml-group-1' }
        expose :access_level, documentation: { type: 'integer', example: 40 }
        expose :member_role_id, documentation: { type: 'integer', example: 12 }, if: ->(instance, _options) do
          instance.group.custom_roles_enabled?
        end
        expose :provider, documentation: { type: 'string', example: 'saml' }
      end
    end
  end
end
