# frozen_string_literal: true

module EE
  module ProjectTeam
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    def members_with_access_level_or_custom_roles(levels: [], member_role_ids: [])
      return ::User.none unless levels.any? || member_role_ids.any?

      users = project.authorized_users

      if levels.any? && member_role_ids.any?
        users = users
          .where(project_authorizations: { access_level: levels })
          .or(users.where(members: { member_role_id: member_role_ids }))
          .joins(:members)
      elsif levels.any?
        users = users.where(project_authorizations: { access_level: levels })
      elsif member_role_ids.any?
        users = users.joins(:members).where(members: { member_role_id: member_role_ids })
      end

      users
    end

    override :add_members
    def add_members(
      users,
      access_level,
      current_user: nil,
      expires_at: nil
    )
      return false if group_member_lock

      super
    end

    override :add_member
    def add_member(user, access_level, current_user: nil, expires_at: nil)
      if group_member_lock && !(user.project_bot? || user.security_policy_bot?)
        return false
      end

      super
    end

    private

    def group_member_lock
      group && group.membership_lock
    end

    override :source_members_for_import
    def source_members_for_import(source_project)
      source_project.project_members.where.not(user: source_project.security_policy_bots).to_a
    end
  end
end
