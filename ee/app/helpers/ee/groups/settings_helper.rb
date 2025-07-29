# frozen_string_literal: true

module EE
  module Groups
    module SettingsHelper
      def unique_project_download_limit_settings_data
        settings = @group.namespace_settings || ::NamespaceSetting.new
        limit = settings.unique_project_download_limit
        interval = settings.unique_project_download_limit_interval_in_seconds
        allowlist = settings.unique_project_download_limit_allowlist
        alertlist = settings.unique_project_download_limit_alertlist
        auto_ban_users = settings.auto_ban_user_on_excessive_projects_download

        {
          group_full_path: @group.full_path,
          max_number_of_repository_downloads: limit,
          max_number_of_repository_downloads_within_time_period: interval,
          git_rate_limit_users_allowlist: allowlist,
          git_rate_limit_users_alertlist: alertlist,
          auto_ban_user_on_excessive_projects_download: auto_ban_users.to_s
        }
      end

      def show_group_ai_settings_general?
        GitlabSubscriptions::Duo.duo_settings_available?(@group.root_ancestor)
      end

      def show_group_ai_settings_page?
        @group.licensed_ai_features_available? && show_gitlab_duo_settings_app?(@group)
      end

      def show_early_access_program_banner?
        return false unless ::Feature.enabled?(:early_access_program_toggle, @current_user)

        !current_user.user_preference.early_access_program_participant? && @group.experiment_features_enabled
      end

      def group_ai_general_settings_helper_data
        {
          on_general_settings_page: 'true',
          redirect_path: edit_group_path(@group)
        }.merge(group_ai_settings_helper_data)
      end

      def group_ai_configuration_settings_helper_data
        {
          on_general_settings_page: 'false',
          redirect_path: group_settings_gitlab_duo_path(@group)
        }.merge(group_ai_settings_helper_data)
      end

      def group_ai_settings_helper_data
        cascading_settings_data = cascading_namespace_settings_tooltip_data(:duo_features_enabled, @group, method(:edit_group_path))[:tooltip_data]
        {
          cascading_settings_data: cascading_settings_data,
          duo_availability: @group.namespace_settings.duo_availability.to_s,
          are_duo_settings_locked: @group.namespace_settings.duo_features_enabled_locked?.to_s,
          experiment_features_enabled: @group.namespace_settings.experiment_features_enabled.to_s,
          duo_core_features_enabled: @group.namespace_settings.duo_core_features_enabled.to_s,
          prompt_cache_enabled: @group.namespace_settings.model_prompt_cache_enabled.to_s,
          are_experiment_settings_allowed: (@group.experiment_settings_allowed? && gitlab_com_subscription?).to_s,
          are_prompt_cache_settings_allowed: (@group.prompt_cache_settings_allowed? && gitlab_com_subscription?).to_s,
          show_early_access_banner: show_early_access_program_banner?.to_s,
          early_access_path: group_early_access_opt_in_path(@group),
          update_id: @group.id,
          duo_workflow_available: current_user.can?(:admin_duo_workflow, @group).to_s,
          duo_workflow_mcp_enabled: @group.duo_workflow_mcp_enabled.to_s,
          is_saas: saas?.to_s
        }
      end

      def group_amazon_q_settings_view_model_data
        {
          group_id: @group.id.to_s,
          init_availability: @group.namespace_settings.duo_availability.to_s,
          init_auto_review_enabled: @group.amazon_q_integration&.auto_review_enabled.present?,
          are_duo_settings_locked: @group.namespace_settings.duo_features_enabled_locked?,
          cascading_settings_data: cascading_namespace_settings_tooltip_raw_data(:duo_features_enabled, @group, method(:edit_group_path))
        }
      end

      def group_amazon_q_settings_view_model_json
        ::Gitlab::Json.generate(group_amazon_q_settings_view_model_data.deep_transform_keys { |k| k.to_s.camelize(:lower) })
      end

      def seat_control_disabled_help_text
        _("Restricted access and user cap cannot be turned on. The group or one of its subgroups or projects is shared externally.")
      end

      private

      def saas?
        ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
      end

      def saas_user_caps_i18n_string(group)
        if ::Feature.enabled?(:saas_user_caps_auto_approve_pending_users_on_cap_increase, group.root_ancestor)
          s_('GroupSettings|After the instance reaches the user cap, any user who is added or requests access must be approved by an administrator. Leave empty for an unlimited user cap. If you change the user cap to unlimited, you must re-enable %{project_sharing_docs_link_start}project sharing%{link_end} and %{group_sharing_docs_link_start}group sharing%{link_end}.')
        else
          s_('GroupSettings|After the instance reaches the user cap, any user who is added or requests access must be approved by an administrator. Leave empty for an unlimited user cap. If you change the user cap to unlimited, you must re-enable %{project_sharing_docs_link_start}project sharing%{link_end} and %{group_sharing_docs_link_start}group sharing%{link_end}. Increasing the user cap does not automatically approve pending users.')
        end
      end
    end
  end
end
