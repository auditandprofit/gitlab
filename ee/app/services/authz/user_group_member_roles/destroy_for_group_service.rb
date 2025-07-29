# frozen_string_literal: true

module Authz
  module UserGroupMemberRoles
    class DestroyForGroupService < BaseService
      attr_reader :user, :group

      def initialize(user, group)
        @user = user
        @group = group
      end

      def execute
        # Deletes one record for the target group and one for each group it was
        # invited to with an assigned member role. Expected volume: ~100 records
        # maximum.
        ids = ::Authz::UserGroupMemberRole.for_user_in_group_and_shared_groups(user, group).ids # rubocop: disable CodeReuse/ActiveRecord -- Very specific use case.

        ::Authz::UserGroupMemberRole.delete_all_with_id(ids).tap do |deleted_count|
          log(deleted_count)
        end
      end

      private

      def log(deleted_count)
        Gitlab::AppJsonLogger.info(
          user_id: @user.id,
          group_id: @group.id,
          'update_user_group_member_roles.event': 'member deleted',
          'update_user_group_member_roles.upserted_count': 0,
          'update_user_group_member_roles.deleted_count': deleted_count
        )
      end
    end
  end
end
