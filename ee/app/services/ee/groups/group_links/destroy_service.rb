# frozen_string_literal: true

module EE
  module Groups
    module GroupLinks
      module DestroyService
        extend ::Gitlab::Utils::Override
        include ::GitlabSubscriptions::CodeSuggestionsHelper

        override :execute
        def execute(one_or_more_links, skip_authorization: false)
          super.tap do |links|
            next unless links.is_a?(Array)

            perform_after_destroy_actions(links)
          end
        end

        private

        def perform_after_destroy_actions(links)
          links.each do |link|
            log_audit_event(link.shared_group, link.shared_with_group)
            enqueue_refresh_add_on_assignments_worker(link)
            destroy_user_group_member_roles(link)
          end
        end

        def log_audit_event(group, shared_with_group)
          audit_context = {
            name: "group_share_with_group_link_removed",
            author: current_user,
            scope: group,
            target: shared_with_group,
            stream_only: false,
            message: "Removed #{shared_with_group.name} " \
                     "from the group #{group.name}"
          }

          ::Gitlab::Audit::Auditor.audit(audit_context)
        end

        def enqueue_refresh_add_on_assignments_worker(link)
          namespace = link.shared_group.root_ancestor

          return unless gitlab_com_subscription?

          GitlabSubscriptions::AddOnPurchases::RefreshUserAssignmentsWorker
            .perform_async(namespace.id)
        end

        def destroy_user_group_member_roles(link)
          return unless ::Feature.enabled?(:cache_user_group_member_roles, link.shared_group.root_ancestor)
          return unless link.member_role_id

          ::Authz::UserGroupMemberRoles::DestroyForSharedGroupWorker
            .perform_async(link.shared_group_id, link.shared_with_group_id)
        end
      end
    end
  end
end
