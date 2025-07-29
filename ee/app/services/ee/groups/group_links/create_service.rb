# frozen_string_literal: true

module EE
  module Groups
    module GroupLinks
      module CreateService
        extend ::Gitlab::Utils::Override
        include GroupLinksHelper

        override :valid_to_create?
        def valid_to_create?
          super && can?(current_user, :invite_group_members, group) && !member_role_too_high?
        end

        override :after_successful_save
        def after_successful_save
          super

          log_audit_event
          create_or_update_seat_assignments
          update_user_group_member_roles
        end

        private

        override :remove_unallowed_params
        def remove_unallowed_params
          params.delete(:member_role_id) unless custom_role_for_group_link_enabled?(group)

          super
        end

        def log_audit_event
          audit_context = {
            name: "group_share_with_group_link_created",
            author: current_user,
            scope: link.shared_group,
            target: link.shared_with_group,
            stream_only: false,
            message: "Invited #{link.shared_with_group.name} " \
                     "to the group #{link.shared_group.name}"
          }

          ::Gitlab::Audit::Auditor.audit(audit_context)
        end

        def create_or_update_seat_assignments
          return unless ::Feature.enabled?(:sam_group_links, root_ancestor)
          return unless ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)

          ::GitlabSubscriptions::SeatAssignments::GroupLinks::CreateOrUpdateSeatsWorker.perform_async(link.id)
        end

        def member_role_too_high?
          group.assigning_role_too_high?(current_user, params[:shared_group_access])
        end

        def update_user_group_member_roles
          return unless ::Feature.enabled?(:cache_user_group_member_roles, link.shared_group.root_ancestor)

          ::Authz::UserGroupMemberRoles::UpdateForSharedGroupWorker.perform_async(link.id)
        end
      end
    end
  end
end
