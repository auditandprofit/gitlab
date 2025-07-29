# frozen_string_literal: true

module EE
  module API
    module Entities
      module Scim
        # rubocop:disable Gitlab/EeOnlyClass -- All existing instance SCIM code
        # currently lives under ee/ and making it compliant requires a larger
        # refactor to be addressed by https://gitlab.com/gitlab-org/gitlab/-/issues/520129.
        class Group < Grape::Entity
          expose :schemas
          expose :id do |group, _options|
            group.scim_group_uid
          end
          expose :display_name, as: :displayName do |group, _options|
            group.saml_group_name
          end
          expose :members, unless: ->(_, opts) { opts[:excluded_attributes]&.include?('members') }
          expose :meta do
            expose :resource_type, as: :resourceType
          end

          private

          DEFAULT_SCHEMA = 'urn:ietf:params:scim:schemas:core:2.0:Group'

          def schemas
            [DEFAULT_SCHEMA]
          end

          def members
            [] # We'll need to implement this if we want to show actual members
          end

          def resource_type
            'Group'
          end
        end
        # rubocop:enable Gitlab/EeOnlyClass
      end
    end
  end
end
