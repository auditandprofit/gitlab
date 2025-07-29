# frozen_string_literal: true

module Groups
  module EnterpriseUsers
    class AssociateService < BaseService
      include Groups::EnterpriseUsers::Associable

      def initialize(group:, user:)
        @group = group
        @user = user
      end

      def execute
        if user.enterprise_user_of_group?(group)
          return error(s_('EnterpriseUsers|The user is already an enterprise user of the group'))
        end

        unless user_matches_the_enterprise_user_definition_for_the_group?(group)
          return error(s_('EnterpriseUsers|The user does not match the "Enterprise User" definition for the group'))
        end

        # Allows the raising of persistent failure and enables it to be retried when called from inside sidekiq.
        # see https://gitlab.com/gitlab-org/gitlab/-/merge_requests/130735#note_1550114699
        @user.update!(user_attributes)

        Notify.user_associated_with_enterprise_group_email(user.id).deliver_later

        log_info(message: 'Associated the user with the enterprise group')

        success
      end

      private

      def user_attributes
        enterprise_user_attributes.merge(::Onboarding::FinishService.new(user).onboarding_attributes)
      end

      def enterprise_user_attributes
        { user_detail_attributes: { enterprise_group_id: group.id, enterprise_group_associated_at: Time.current } }
      end
    end
  end
end
