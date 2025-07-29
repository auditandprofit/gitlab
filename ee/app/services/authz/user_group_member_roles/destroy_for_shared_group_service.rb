# frozen_string_literal: true

module Authz
  module UserGroupMemberRoles
    class DestroyForSharedGroupService < BaseService
      attr_reader :shared_group, :shared_with_group

      def initialize(shared_group, shared_with_group)
        @shared_group = shared_group
        @shared_with_group = shared_with_group
      end

      def execute
        ::Authz::UserGroupMemberRole
          .in_shared_group(shared_group, shared_with_group)
          .delete_all
          .tap { |deleted_count| log(deleted_count) }
      end

      private

      def log(deleted_count)
        Gitlab::AppJsonLogger.info(
          shared_group_id: @shared_group.id,
          shared_with_group_id: @shared_with_group.id,
          'update_user_group_member_roles.event': 'group_group_link deleted',
          'update_user_group_member_roles.upserted_count': 0,
          'update_user_group_member_roles.deleted_count': deleted_count
        )
      end
    end
  end
end
