# frozen_string_literal: true

module Authz
  module MemberRoleInSharedGroup
    extend ActiveSupport::Concern

    # Determine effective member role of a user in a shared group.
    # Docs: https://docs.gitlab.com/user/custom_roles/#assign-a-custom-role-to-an-invited-group
    #
    # Usage:
    # - ActiveRecord: Member.select(member_role_id_in_shared_group)
    # - Arel: Member.arel_table.project(member_role_id_in_shared_group)
    #
    # This method assumes the query selects from group_group_links and members
    # tables joined on group_group_links.shared_with_group_id = members.source_id.
    #
    # FROM group_group_links ggl
    #   INNER JOIN members m ON
    #     ggl.shared_with_group_id = m.source_id
    def member_role_id_in_shared_group
      group_access_level = group_group_links[:group_access]
      group_member_role_id = group_group_links[:member_role_id]

      user_access_level = members[:access_level]
      user_member_role_id = members[:member_role_id]

      Arel::Nodes::Case.new
        .when(user_access_level.gt(group_access_level)).then(group_member_role_id)
        .when(user_access_level.lt(group_access_level)).then(user_member_role_id)
        .when(group_member_role_id.eq(nil)).then(nil)
        .else(user_member_role_id)
    end

    def members
      ::Member.arel_table
    end

    def group_group_links
      ::GroupGroupLink.arel_table
    end
  end
end
