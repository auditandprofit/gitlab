# frozen_string_literal: true

module Types
  module Members
    # Interface for roles that can be assigned to group or project members.
    module MemberRoleInterface
      include BaseInterface

      field :members_count,
        GraphQL::Types::Int,
        experiment: { milestone: '17.3' },
        description: 'Number of times the role has been directly assigned to a group or project member.'

      field :users_count,
        GraphQL::Types::Int,
        experiment: { milestone: '17.5' },
        description: 'Number of users who have been directly assigned the role in at least one group or project.'
    end
  end
end
