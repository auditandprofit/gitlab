# frozen_string_literal: true

module EE
  module Projects
    module ProjectMembersController
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      MEMBER_PER_PAGE_LIMIT = 50

      override :index
      def index
        super

        # rubocop:disable Gitlab/ModuleWithInstanceVariables -- Need to initialize pending members
        @pending_promotion_members_count = pending_promotion_members_count
        # rubocop:enable Gitlab/ModuleWithInstanceVariables
      end

      private

      prepended do
        before_action do
          push_frontend_feature_flag(:show_overage_on_role_promotion)
          push_frontend_feature_flag(:show_role_details_in_drawer, @project)
        end
      end

      override :invited_members
      def invited_members
        super.or(members.awaiting.with_invited_user_state)
      end

      override :non_invited_members
      def non_invited_members
        super.non_awaiting
      end

      def pending_promotion_members_count
        return unless can?(current_user, :admin_project_member, project)

        ::GitlabSubscriptions::MemberManagement::MemberApprovalFinder
          .new(current_user: current_user, params: params, source: project)
          .execute
          .count
      end
    end
  end
end
