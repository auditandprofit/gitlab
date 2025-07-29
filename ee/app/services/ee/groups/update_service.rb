# frozen_string_literal: true

module EE
  module Groups
    module UpdateService
      extend ::Gitlab::Utils::Override
      EE_SETTINGS_PARAMS = [
        :prevent_forking_outside_group,
        :remove_dormant_members,
        :remove_dormant_members_period,
        :allow_enterprise_bypass_placeholder_confirmation,
        :enterprise_bypass_expires_at
      ].freeze

      override :execute
      def execute
        if changes_file_template_project_id?
          check_file_template_project_id_change!
          return false if group.errors.present?
        end

        prepare_params!

        handle_changes

        return false if group.errors.present?

        super.tap { |success| log_audit_events if success }
      end

      private

      override :after_update
      def after_update
        super

        if group.saved_change_to_max_personal_access_token_lifetime?
          group.update_personal_access_tokens_lifetime
        end

        update_cascading_settings
        handle_pending_members
        update_amazon_q!
        update_duo_workflow!
        publish_ai_settings_changed_event
        schedule_remove_dormant_users
      end

      override :before_assignment_hook
      def before_assignment_hook(group, params)
        super

        # Repository size limit comes as MB from the view
        limit = params.delete(:repository_size_limit)
        group.repository_size_limit = ::Gitlab::Utils.try_megabytes_to_bytes(limit) if limit
      end

      override :remove_unallowed_params
      def remove_unallowed_params
        unless current_user&.admin?
          params.delete(:shared_runners_minutes_limit)
          params.delete(:extra_shared_runners_minutes_limit)
        end

        params.delete(:repository_size_limit) unless current_user&.can_admin_all_resources?

        insight_project_id = params.dig(:insight_attributes, :project_id)
        if insight_project_id
          group_projects = ::GroupProjectsFinder.new(group: group, current_user: current_user, options: { exclude_shared: true, include_subgroups: true }).execute
          params.delete(:insight_attributes) unless group_projects.exists?(insight_project_id) # rubocop:disable CodeReuse/ActiveRecord
        end

        unless ::Gitlab::Saas.feature_available?(:repositories_web_based_commit_signing) && ::Feature.enabled?(:use_web_based_commit_signing_enabled, group)
          params.delete(:web_based_commit_signing_enabled)
        end

        super
      end

      def changes_file_template_project_id?
        return false unless params.key?(:file_template_project_id)

        params[:file_template_project_id] != group.checked_file_template_project_id
      end

      def check_file_template_project_id_change!
        unless can?(current_user, :admin_group, group)
          group.errors.add(:file_template_project_id, s_('GroupSettings|cannot be changed by you'))
          return
        end

        # Clearing the current value is always permitted if you can admin the group
        return unless params[:file_template_project_id].present?

        # Ensure the user can see the new project, avoiding information disclosures
        return if file_template_project_visible?

        group.errors.add(:file_template_project_id, 'is invalid')
      end

      def file_template_project_visible?
        ::ProjectsFinder.new(
          current_user: current_user,
          project_ids_relation: [params[:file_template_project_id]]
        ).execute.exists?
      end

      def prepare_params!
        destroy_association_if_project_is_empty(:insight)
        destroy_association_if_project_is_empty(:analytics_dashboards_pointer, project_key: :target_project_id)
      end

      def destroy_association_if_project_is_empty(association_name, project_key: :project_id)
        attributes_path = :"#{association_name}_attributes"
        if params.dig(attributes_path, project_key) == ''
          params[attributes_path][:_destroy] = true
          params[attributes_path].delete(project_key)
        end
      end

      override :handle_changes
      def handle_changes
        handle_allowed_email_domains_update
        handle_ip_restriction_update
        super
      end

      def handle_ip_restriction_update
        comma_separated_ranges = params.delete(:ip_restriction_ranges)

        return if comma_separated_ranges.nil?

        # rubocop:disable Gitlab/ModuleWithInstanceVariables
        @ip_restriction_update_service = IpRestrictions::UpdateService.new(current_user, group, comma_separated_ranges)
        @ip_restriction_update_service.execute
        # rubocop:enable Gitlab/ModuleWithInstanceVariables
      end

      def handle_allowed_email_domains_update
        return unless params.key?(:allowed_email_domains_list)

        comma_separated_domains = params.delete(:allowed_email_domains_list)

        # rubocop:disable Gitlab/ModuleWithInstanceVariables -- Reason: We need this instance to log audit event post save
        @allowed_email_domains_update_service = AllowedEmailDomains::UpdateService.new(current_user, group, comma_separated_domains)
        @allowed_email_domains_update_service.execute
        # rubocop:enable Gitlab/ModuleWithInstanceVariables
      end

      override :allowed_settings_params
      def allowed_settings_params
        @allowed_settings_params ||= super + EE_SETTINGS_PARAMS
      end

      def log_audit_events
        @ip_restriction_update_service&.log_audit_event # rubocop:disable Gitlab/ModuleWithInstanceVariables
        @allowed_email_domains_update_service&.log_audit_event(group.allowed_email_domains.map(&:domain)) # rubocop:disable Gitlab/ModuleWithInstanceVariables

        ::Namespaces::GroupChangesAuditor.new(current_user, group).execute
      end

      def update_cascading_settings
        previous_changes = group.namespace_settings.previous_changes

        if previous_changes.include?(:duo_features_enabled)
          ::Namespaces::CascadeDuoFeaturesEnabledWorker.perform_async(group.id)
        end

        if previous_changes.include?(:web_based_commit_signing_enabled)
          ::Namespaces::CascadeWebBasedCommitSigningEnabledWorker.perform_async(group.id)
        end
      end

      def handle_pending_members
        settings = group.namespace_settings

        case settings.previous_changes[:seat_control]
        when %w[user_cap off]
          ::Members::ActivateService.for_group(group).execute(current_user: current_user)
        when %w[user_cap block_overages]
          ::Members::DeletePendingMembersWorker.perform_async(group.id, current_user.id)
        end
      end

      def update_amazon_q!
        return unless ::Ai::AmazonQ.connected?

        integration_params = {
          availability: params[:duo_availability], auto_review_enabled: params[:amazon_q_auto_review_enabled]
        }.compact

        if group.amazon_q_integration.update(integration_params)
          PropagateIntegrationWorker.perform_async(group.amazon_q_integration.id)
        end

        return unless params[:duo_availability] == 'never_on'

        amazon_q_service_account_user = ::Ai::Setting.instance.amazon_q_service_account_user
        ::Ai::ServiceAccountMemberRemoveService.new(current_user, group, amazon_q_service_account_user).execute
      end

      def update_duo_workflow!
        return unless ::Ai::DuoWorkflow.connected? && params[:duo_availability] == 'never_on'

        duo_workflow_service_account_user = ::Ai::Setting.instance.duo_workflow_service_account_user
        ::Ai::ServiceAccountMemberRemoveService.new(current_user, group, duo_workflow_service_account_user).execute
      end

      def publish_ai_settings_changed_event
        return unless ai_settings_changed?

        ::Gitlab::EventStore.publish(
          ::NamespaceSettings::AiRelatedSettingsChangedEvent.new(data: { group_id: group.id })
        )
      end

      def schedule_remove_dormant_users
        return unless group.namespace_settings.previous_changes.include?(:remove_dormant_members)
        return unless group.namespace_settings.remove_dormant_members

        ::Namespaces::RemoveDormantMembersWorker.perform_with_capacity
      end

      def ai_settings_changed?
        return false unless group.namespace_settings

        ::NamespaceSettings::AiRelatedSettingsChangedEvent::AI_RELATED_SETTINGS.any? do |setting|
          group.namespace_settings.saved_change_to_attribute?(setting)
        end
      end

      def non_assignable_group_params
        super + [:amazon_q_auto_review_enabled]
      end
    end
  end
end
