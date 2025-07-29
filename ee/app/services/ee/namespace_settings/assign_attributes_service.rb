# frozen_string_literal: true

module EE
  # This class is responsible for updating the namespace settings of a specific group.
  #
  module NamespaceSettings
    module AssignAttributesService
      extend ::Gitlab::Utils::Override

      override :execute
      def execute
        unless can_update_prevent_forking?
          group.errors.add(
            :prevent_forking_outside_group,
            s_('GroupSettings|Prevent forking setting was not saved')
          )
        end

        unless can_update_service_access_tokens_expiration_enforced?
          group.errors.add(
            :service_access_tokens_expiration_enforced,
            s_('GroupSettings|Service access tokens expiration enforced setting was not saved')
          )
        end

        validate_settings_param_for_admin(
          param_key: :duo_features_enabled,
          user_policy: :admin_group
        )
        validate_settings_param_for_admin(
          param_key: :lock_duo_features_enabled,
          user_policy: :admin_group
        )
        validate_settings_param_for_root_group(
          param_key: :disable_invite_members,
          user_policy: :owner_access
        )
        validate_settings_param_for_root_group(
          param_key: :web_based_commit_signing_enabled,
          user_policy: :admin_group
        )

        handle_web_based_commit_signing_lock

        super
      end

      private

      def can_update_prevent_forking?
        return true unless settings_params.key?(:prevent_forking_outside_group)

        if can?(current_user, :change_prevent_group_forking, group)
          true
        else
          settings_params.delete(:prevent_forking_outside_group)

          false
        end
      end

      def can_update_service_access_tokens_expiration_enforced?
        return true unless settings_params.key?(:service_access_tokens_expiration_enforced)

        return true if group.root? && can?(current_user, :admin_service_accounts, group)

        settings_params.delete(:service_access_tokens_expiration_enforced)
        false
      end

      def handle_web_based_commit_signing_lock
        return unless settings_params.key?(:web_based_commit_signing_enabled)

        settings_params[:lock_web_based_commit_signing_enabled] =
          !!settings_params[:web_based_commit_signing_enabled]
      end
    end
  end
end
