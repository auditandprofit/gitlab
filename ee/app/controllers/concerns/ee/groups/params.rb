# frozen_string_literal: true

module EE
  module Groups
    module Params
      extend ::Gitlab::Utils::Override
      include PreventForkingHelper
      include ServiceAccessTokenExpirationHelper

      override :group_params_attributes
      def group_params_attributes
        super + group_params_ee
      end

      override :group_feature_attributes
      def group_feature_attributes
        return super unless current_group&.licensed_feature_available?(:group_wikis)

        super + [:wiki_access_level]
      end

      private

      # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize -- The .tap block
      # requires many necessary checks for each parameter.
      def group_params_ee
        [
          :membership_lock,
          :repository_size_limit,
          :new_user_signups_cap,
          :seat_control,
          :remove_dormant_members,
          :remove_dormant_members_period
        ].tap do |params_ee|
          params_ee << { insight_attributes: [:id, :project_id, :_destroy] } if current_group&.insights_available?

          if current_group&.feature_available?(:group_level_analytics_dashboard)
            params_ee << { analytics_dashboards_pointer_attributes: [:id, :target_project_id, :_destroy] }
          end

          if current_group&.feature_available?(:custom_file_templates_for_namespace)
            params_ee << :file_template_project_id
          end

          params_ee << :custom_project_templates_group_id if current_group&.group_project_template_available?
          params_ee << :ip_restriction_ranges if current_group&.licensed_feature_available?(:group_ip_restriction)
          params_ee << :allowed_email_domains_list if current_group&.feature_available?(:group_allowed_email_domains)
          params_ee << :max_pages_size if can?(current_user, :update_max_pages_size)

          if current_group&.personal_access_token_expiration_policy_available?
            params_ee << :max_personal_access_token_lifetime
          end

          params_ee << :prevent_forking_outside_group if can_change_prevent_forking?(current_user, current_group)

          if can_change_service_access_tokens_expiration?(current_user, current_group)
            params_ee << :service_access_tokens_expiration_enforced
          end

          params_ee << :enforce_ssh_certificates if current_group&.ssh_certificates_available?

          if can?(current_user, :modify_value_stream_dashboard_settings, current_group)
            params_ee << { value_stream_dashboard_aggregation_attributes: [:enabled] }
          end

          if experiment_settings_allowed?
            params_ee.push(:experiment_features_enabled, :early_access_program_participant)
          end

          if licensed_ai_features_available?
            params_ee.push(%i[duo_features_enabled duo_core_features_enabled lock_duo_features_enabled
              duo_availability prompt_cache_enabled])
          end

          params_ee << :disable_personal_access_tokens if current_group&.disable_personal_access_tokens_available?

          if current_group&.can_manage_extensions_marketplace_for_enterprise_users?
            params_ee << :enterprise_users_extensions_marketplace_enabled
          end

          if can?(current_user, :admin_group, current_group) &&
              current_group.licensed_feature_available?(:group_webhooks)
            params_ee << :extended_grat_expiry_webhooks_execute
          end

          if ::Feature.enabled?(:manage_pat_by_group_owners_ready, current_group) &&
              can?(current_user, :admin_group, current_group)
            params_ee << :require_dpop_for_manage_api_endpoints
          end

          if current_group&.root? &&
              can?(current_user, :owner_access, current_group)
            params_ee << :disable_invite_members
          end

          if enterprise_bypass_placeholders_allowed?
            params_ee << :allow_enterprise_bypass_placeholder_confirmation
            params_ee << :enterprise_bypass_expires_at
          end
        end
      end
      # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize

      def experiment_settings_allowed?
        current_group&.experiment_settings_allowed?
      end

      def prompt_cache_settings_allowed?
        current_group&.prompt_cache_settings_allowed?
      end

      def licensed_ai_features_available?
        current_group&.licensed_ai_features_available?
      end

      def current_group
        @group
      end

      def enterprise_bypass_placeholders_allowed?
        ::Feature.enabled?(:group_owner_placeholder_confirmation_bypass, current_group) &&
          current_group&.domain_verification_available?
      end
    end
  end
end
