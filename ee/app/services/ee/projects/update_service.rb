# frozen_string_literal: true

module EE
  module Projects
    module UpdateService
      extend ::Gitlab::Utils::Override

      DEFAULT_BRANCH_CHANGE_AUDIT_TYPE = 'project_default_branch_updated'
      DEFAULT_BRANCH_CHANGE_AUDIT_MESSAGE = "Default branch changed from %s to %s"
      PROJECT_TOPIC_CHANGE_AUDIT_TYPE = 'project_topics_updated'

      PULL_MIRROR_ATTRIBUTES = %i[
        mirror
        mirror_user_id
        import_url
        username_only_import_url
        mirror_trigger_builds
        only_mirror_protected_branches
        mirror_overwrites_diverged_branches
        import_data_attributes
        mirror_branch_regex
      ].freeze

      override :execute
      def execute
        wiki_was_enabled = project.wiki_enabled?

        shared_runners_setting
        mirror_user_setting
        mirror_branch_setting

        return update_failed! if project.errors.any?

        if params[:project_setting_attributes].present?
          suggested_reviewers_already_enabled = project.suggested_reviewers_enabled
          unless project.suggested_reviewers_available?
            params[:project_setting_attributes].delete(:suggested_reviewers_enabled)
          end
        end

        prepare_analytics_dashboards_params!

        validate_web_based_commit_signing_enabled

        result = super do
          assign_repository_size_limit
        end

        if result[:status] == :success
          refresh_merge_trains(project)

          log_audit_events

          sync_wiki_on_enable if !wiki_was_enabled && project.wiki_enabled?
          project.import_state.force_import_job! if params[:mirror].present? && project.mirror?
          project.remove_import_data if project.previous_changes.include?('mirror') && !project.mirror?
          update_amazon_q_service_account!
          update_duo_workflow_service_account!

          suggested_reviewers_already_enabled ? trigger_project_deregistration : trigger_project_registration
        end

        result
      end

      private

      def assign_repository_size_limit
        limit = params.delete(:repository_size_limit)
        return unless limit

        # Repository size limit comes as MB from the view
        project.repository_size_limit = ::Gitlab::Utils.try_megabytes_to_bytes(limit)
      end

      def validate_web_based_commit_signing_enabled
        return unless params.key?(:web_based_commit_signing_enabled)

        return if ::Gitlab::Saas.feature_available?(:repositories_web_based_commit_signing) &&
          ::Feature.enabled?(:use_web_based_commit_signing_enabled, project) &&
          !namespace_settings_enabled?

        params.delete(:web_based_commit_signing_enabled)
      end

      def namespace_settings_enabled?
        project.group&.namespace_settings&.web_based_commit_signing_enabled
      end

      def prepare_analytics_dashboards_params!
        if params[:analytics_dashboards_pointer_attributes] &&
            params[:analytics_dashboards_pointer_attributes][:target_project_id].blank?

          params[:analytics_dashboards_pointer_attributes][:_destroy] = true
          params[:analytics_dashboards_pointer_attributes].delete(:target_project_id)
        end
      end

      def trigger_project_registration
        return unless params[:project_setting_attributes].present? &&
          params[:project_setting_attributes][:suggested_reviewers_enabled] == '1'

        return unless can_update_suggested_reviewers_setting?

        ::Projects::RegisterSuggestedReviewersProjectWorker.perform_async(project.id, current_user.id)
      end

      def trigger_project_deregistration
        return unless params[:project_setting_attributes].present? &&
          params[:project_setting_attributes][:suggested_reviewers_enabled] == '0'

        return unless project.suggested_reviewers_available?

        ::Projects::DeregisterSuggestedReviewersProjectWorker.perform_async(project.id, current_user.id)
      end

      def can_update_suggested_reviewers_setting?
        project.suggested_reviewers_available? && current_user.can?(:create_resource_access_tokens, project)
      end

      override :remove_unallowed_params
      def remove_unallowed_params
        super

        unless project.licensed_feature_available?(:external_status_checks)
          params.delete(:only_allow_merge_if_all_status_checks_passed)
        end

        params.delete(:repository_size_limit) unless current_user&.can_admin_all_resources?
      end

      override :validate_default_branch_change
      def validate_default_branch_change
        if changing_default_branch? && default_branch_update_blocked_by_security_policy?
          raise_validation_error(s_("UpdateProject|Updating default branch is blocked by security policy"))
        end

        super
      end

      override :after_default_branch_change
      def after_default_branch_change(previous_default_branch)
        audit_context = {
          name: DEFAULT_BRANCH_CHANGE_AUDIT_TYPE,
          author: current_user,
          scope: project,
          target: project,
          message: format(DEFAULT_BRANCH_CHANGE_AUDIT_MESSAGE, previous_default_branch, project.default_branch),
          target_details: project.full_path,
          additional_details: {
            from: previous_default_branch,
            to: project.default_branch
          }
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)

        ::Security::ScanResultPolicies::SyncProjectWorker.perform_async(project.id)
      end

      override :audit_topic_change
      def audit_topic_change(from:)
        # reload project topics without affecting shared project variable, as that leads to unwanted side effects
        # when publishing events
        to = ::Project.find(project.id).topic_list
        topics_changed = from != to

        return unless topics_changed

        ::Gitlab::Audit::Auditor.audit(
          name: PROJECT_TOPIC_CHANGE_AUDIT_TYPE,
          author: current_user,
          scope: project,
          target: project,
          message: "topics changed to: '#{to.join(',')}'",
          target_details: project.full_path,
          additional_details: {
            event_name: PROJECT_TOPIC_CHANGE_AUDIT_TYPE,
            from: from,
            to: to
          }
        )
      end

      def default_branch_update_blocked_by_security_policy?
        ::Security::SecurityOrchestrationPolicies::DefaultBranchUpdationCheckService.new(project: project).execute
      end

      # A user who enables shared runners must meet the credit card requirement if
      # there is one.
      def shared_runners_setting
        return unless params[:shared_runners_enabled]
        return if project.shared_runners_enabled
        return if user_can_enable_shared_runners?

        project.errors.add(:shared_runners_enabled, _('cannot be enabled until identity verification is completed'))
      end

      def user_can_enable_shared_runners?
        ::Users::IdentityVerification::AuthorizeCi.new(
          user: current_user,
          project: project
        ).user_can_enable_shared_runners?
      end

      # A user who changes any aspect of pull mirroring settings must be made
      # into the mirror user, to prevent them from acquiring capabilities
      # owned by the previous user, such as writing to a protected branch.
      #
      # Only admins can set the mirror user to be an arbitrary user.
      def mirror_user_setting
        return unless PULL_MIRROR_ATTRIBUTES.any? { |symbol| params.key?(symbol) }

        if params[:mirror_user_id] && params[:mirror_user_id] != project.mirror_user_id
          project.errors.add(:mirror_user_id, 'is invalid') unless current_user&.admin?
        else
          params[:mirror_user_id] = current_user.id
        end
      end

      def mirror_branch_setting
        params[:only_mirror_protected_branches] = false if params[:mirror_branch_regex].present?
        params[:mirror_branch_regex] = nil if params[:only_mirror_protected_branches]
      end

      def log_audit_events
        ::Projects::ProjectChangesAuditor.new(current_user, project).execute
      end

      def sync_wiki_on_enable
        project.wiki_repository.geo_handle_after_update if project.wiki_repository
      end

      def refresh_merge_trains(project)
        return unless project.merge_pipelines_were_disabled?

        MergeTrains::Train.all_for_project(project).each(&:refresh_async)
      end

      def update_amazon_q_service_account!
        duo_features_enabled = params.dig(:project_setting_attributes, :duo_features_enabled)

        return unless duo_features_enabled.present? && ::Ai::AmazonQ.connected?

        amazon_q_service_account_user = ::Ai::Setting.instance.amazon_q_service_account_user
        update_service_account(amazon_q_service_account_user)

        integration_params =
          if duo_features_enabled == 'true'
            { availability: 'default_on', auto_review_enabled: params[:amazon_q_auto_review_enabled] }
          else
            { availability: 'never_on', auto_review_enabled: false }
          end

        project.amazon_q_integration.update(integration_params.compact)
      end

      def update_duo_workflow_service_account!
        return unless ::Ai::DuoWorkflow.connected?

        duo_workflow_service_account_user = ::Ai::Setting.instance.duo_workflow_service_account_user
        update_service_account(duo_workflow_service_account_user)
      end

      def update_service_account(service_account_user)
        duo_features_enabled = params.dig(:project_setting_attributes, :duo_features_enabled)

        return unless duo_features_enabled.present?

        service = if duo_features_enabled == 'true'
                    ::Ai::ServiceAccountMemberAddService.new(project, service_account_user)
                  else
                    ::Ai::ServiceAccountMemberRemoveService.new(current_user, project, service_account_user)
                  end

        service.execute
      end

      def non_assignable_project_params
        super + [:amazon_q_auto_review_enabled]
      end
    end
  end
end
