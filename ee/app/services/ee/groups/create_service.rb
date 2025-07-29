# frozen_string_literal: true

module EE
  module Groups
    module CreateService
      extend ::Gitlab::Utils::Override

      AUDIT_EVENT_TYPE = 'group_created'
      AUDIT_EVENT_MESSAGE = 'Added group'

      private

      override :valid?
      def valid?
        return false unless super
        return true unless current_user.requires_identity_verification_to_create_group?(group)

        identity_verification_error

        false
      end

      def ensure_runner_registration_token_disabled_on_com
        return unless group.parent.nil?
        return if ::Gitlab::CurrentSettings.gitlab_dedicated_instance?
        return unless ::Gitlab.com? # rubocop: disable Gitlab/AvoidGitlabInstanceChecks -- this is not based on a feature, but indeed on the location of the code

        group.allow_runner_registration_token = false
      end

      override :after_build_hook
      def after_build_hook
        super

        # Repository size limit comes as MB from the view
        limit = params.delete(:repository_size_limit)
        group.repository_size_limit = ::Gitlab::Utils.try_megabytes_to_bytes(limit) if limit

        ensure_runner_registration_token_disabled_on_com
      end

      override :after_successful_creation_hook
      def after_successful_creation_hook
        super

        log_audit_event
      end

      override :remove_unallowed_params
      def remove_unallowed_params
        unless current_user&.admin?
          params.delete(:shared_runners_minutes_limit)
          params.delete(:extra_shared_runners_minutes_limit)
        end

        params.delete(:repository_size_limit) unless current_user&.can_admin_all_resources?
        params.delete(:remove_dormant_members)
        params.delete(:remove_dormant_members_period)

        super
      end

      def log_audit_event
        audit_context = {
          name: AUDIT_EVENT_TYPE,
          author: current_user,
          scope: group,
          target: group,
          message: AUDIT_EVENT_MESSAGE,
          target_details: group.full_path
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end

      def identity_verification_error
        ::Gitlab::AppLogger.info(
          message: 'User has reached group creation limit',
          reason: 'Identity verification required',
          class: self.class.name,
          username: current_user.username
        )

        group.errors.add(
          :identity_verification,
          s_('CreateGroup|You have reached the group limit until you verify your account.')
        )
      end
    end
  end
end
