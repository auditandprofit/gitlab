# frozen_string_literal: true

module Authz
  module UserGroupMemberRoles
    class UpdateForGroupService < BaseService
      include ::Authz::MemberRoleInSharedGroup

      attr_reader :user, :group, :member

      def initialize(member)
        @user = member.user
        @group = member.source
        @member = member
        @upserted_count = 0
        @deleted_count = 0
      end

      def execute
        # Upserts/deletes one record for the target group and one for each group
        # it was invited to with an assigned member role. Expected volume: at
        # least one to and at most a few hundred records.

        return if member.pending?
        return unless member.active?

        attrs = [user_group_member_role_in_group] + user_group_member_roles_in_shared_groups
        attrs = attrs.map { |a| HashWithIndifferentAccess.new(a) }

        to_delete, to_add = attrs.partition { |a| a[:member_role_id].nil? }
        to_delete = to_delete.pluck(:id).compact # rubocop:disable Database/AvoidUsingPluckWithoutLimit, CodeReuse/ActiveRecord -- Array#pluck

        @deleted_count += ::Authz::UserGroupMemberRole.delete_all_with_id(to_delete) unless to_delete.empty?

        to_add = to_add.map { |a| a.except(:id) }
        in_group, in_shared_groups = to_add.partition { |a| a[:shared_with_group_id].nil? }

        unless in_group.empty?
          ::Authz::UserGroupMemberRole
            .upsert_all(in_group, unique_by: %i[user_id group_id])
            .tap { |result| @upserted_count += result.count }
        end

        ::Authz::UserGroupMemberRole
          .upsert_all(in_shared_groups, unique_by: %i[user_id group_id shared_with_group_id])
          .tap { |result| @upserted_count += result.count } unless in_shared_groups.empty?

        log
      end

      private

      def user_group_member_role_in_group
        existing = Authz::UserGroupMemberRole.for_user_in_group(user, group)

        { id: existing&.id, user_id: user.id, group_id: group.id, member_role_id: member.member_role_id,
          shared_with_group_id: nil }
      end

      def user_group_member_roles_in_shared_groups
        # Get all other groups shared to the group where the user is a member.
        # For each, determine which member role (user's member role in the
        # invited group or member role assigned to the invited group) should
        # take effect for the user.
        query = group_group_links
          .join(members).on(user_is_member_of_shared_with_group(user, group))
          # Left join with user_group_member_roles to retrieve ids of existing
          # records to delete
          .join(user_group_member_roles, Arel::Nodes::OuterJoin).on(
            user_group_member_roles[:user_id].eq(members[:user_id])
            .and(user_group_member_roles[:group_id].eq(group_group_links[:shared_group_id]))
            .and(user_group_member_roles[:shared_with_group_id].eq(group_group_links[:shared_with_group_id]))
          )
          .project(
            user_group_member_roles[:id],
            members[:user_id],
            group_group_links[:shared_group_id].as('group_id'),
            member_role_id_in_shared_group,
            group_group_links[:shared_with_group_id])
          .to_sql

        results = ::Authz::UserGroupMemberRole.connection.select_all query
        results.to_a
      end

      def user_is_member_of_shared_with_group(user, group)
        group_group_links[:shared_with_group_id].eq(group.id)
          .and(members[:user_id].eq(user.id))
          .and(members[:source_id].eq(group_group_links[:shared_with_group_id]))
          .and(members[:source_type].eq('Namespace'))
          .and(members[:requested_at].eq(nil))
          .and(members[:state].eq(::Member::STATE_ACTIVE))
          .and(members[:access_level].gt(Gitlab::Access::MINIMAL_ACCESS))
      end

      def user_group_member_roles
        ::Authz::UserGroupMemberRole.arel_table
      end

      def log
        Gitlab::AppJsonLogger.info(
          user_id: @user.id,
          group_id: @group.id,
          'update_user_group_member_roles.event': 'member created/updated',
          'update_user_group_member_roles.upserted_count': @upserted_count,
          'update_user_group_member_roles.deleted_count': @deleted_count
        )
      end
    end
  end
end
