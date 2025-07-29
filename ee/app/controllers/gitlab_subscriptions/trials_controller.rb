# frozen_string_literal: true

# EE:SaaS
module GitlabSubscriptions
  class TrialsController < ApplicationController
    include GitlabSubscriptions::Trials::DuoCommon
    extend ::Gitlab::Utils::Override

    prepend_before_action :authenticate_user! # must run before other before_actions that expect current_user to be set
    before_action :eligible_namespaces # needed when namespace_id isn't provided or is 0(new group)

    feature_category :plan_provisioning
    urgency :low

    def new
      track_event('render_trial_page')

      render GitlabSubscriptions::Trials::Ultimate::TrialFormComponent
               .new(
                 user: current_user,
                 eligible_namespaces: @eligible_namespaces,
                 params: form_params
               )
    end

    def create
      @result = GitlabSubscriptions::Trials::UltimateCreateService.new(
        step: general_params[:step], params: create_params, user: current_user
      ).execute

      if @result.success?
        # lead and trial created
        # We go off the add on here instead of the subscription for the expiration date since
        # in the premium with ultimate trial case the trial_ends_on does not exist on the
        # gitlab_subscription record.
        flash[:success] = success_flash_message(@result.payload[:add_on_purchase])

        redirect_to trial_success_path(@result.payload[:namespace])
      elsif @result.reason == GitlabSubscriptions::Trials::UltimateCreateService::NOT_FOUND
        render_404
      else
        render GitlabSubscriptions::Trials::Ultimate::CreationFailureComponent.new(
          user: current_user, eligible_namespaces: @eligible_namespaces, params: form_params, result: @result
        )
      end
    end

    private

    def create_params
      params.permit(
        *::Onboarding::StatusPresenter::GLM_PARAMS,
        :company_name, :first_name, :last_name, :phone_number,
        :country, :state, :new_group_name, :namespace_id
      ).with_defaults(organization_id: Current.organization.id).to_h
    end

    def form_params
      params.permit(*::Onboarding::StatusPresenter::GLM_PARAMS, :new_group_name, :namespace_id,
        :first_name, :last_name, :company_name, :phone_number, :country, :state
      )
    end

    def trial_success_path(namespace)
      if discover_group_security_flow?
        group_security_dashboard_path(namespace)
      else
        group_settings_gitlab_duo_path(namespace)
      end
    end

    def authenticate_user!
      return if current_user

      redirect_to(
        new_trial_registration_path(::Onboarding::StatusPresenter.glm_tracking_params(params)), # rubocop:disable Rails/StrongParams -- method performs strong params
        alert: I18n.t('devise.failure.unauthenticated')
      )
    end

    def eligible_namespaces
      @eligible_namespaces = GitlabSubscriptions::Trials.eligible_namespaces_for_user(current_user)
    end

    def discover_group_security_flow?
      %w[discover-group-security discover-project-security].include?(create_params[:glm_content])
    end

    def should_check_eligibility?
      namespace_id = general_params[:namespace_id]
      namespace_id.present? && !GitlabSubscriptions::Trials.creating_group_trigger?(namespace_id)
    end

    override :eligible_for_trial?
    def eligible_for_trial?
      !should_check_eligibility? || namespace_in_params_eligible?
    end

    def success_flash_message(add_on_purchase)
      if discover_group_security_flow?
        s_("BillingPlans|Congratulations, your free trial is activated.")
      else
        safe_format(
          s_(
            "BillingPlans|You have successfully started an Ultimate and GitLab Duo Enterprise trial that will " \
              "expire on %{exp_date}. " \
              "To give members access to new GitLab Duo Enterprise features, " \
              "%{assign_link_start}assign them%{assign_link_end} to GitLab Duo Enterprise seats."
          ),
          success_doc_link,
          exp_date: l(add_on_purchase.expires_on.to_date, format: :long)
        )
      end
    end
  end
end

GitlabSubscriptions::TrialsController.prepend_mod
