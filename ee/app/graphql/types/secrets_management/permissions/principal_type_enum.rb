# frozen_string_literal: true

module Types
  module SecretsManagement
    module Permissions
      class PrincipalTypeEnum < BaseEnum
        graphql_name 'PrincipalType'
        description 'Types of principal that can have secret permissions'

        value 'USER', value: 'User', description: 'user.'
        value 'GROUP', value: 'Group', description: 'group.'
        value 'MEMBER_ROLE', value: 'MemberRole', description: 'member role.'
        value 'ROLE', value: 'Role', description: 'predefined role.'
      end
    end
  end
end
