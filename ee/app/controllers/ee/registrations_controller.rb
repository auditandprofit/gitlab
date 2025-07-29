# frozen_string_literal: true

module EE
  module RegistrationsController
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override
    include ::Gitlab::Utils::StrongMemoize
    include ::Users::IdentityVerificationHelper
    include ::Gitlab::Tracking::Helpers::InvalidUserErrorEvent

    prepended do
      include Arkose::ContentSecurityPolicy
      include Arkose::TokenVerifiable
      include GoogleAnalyticsCSP
      include GoogleSyndicationCSP

      skip_before_action :check_captcha, if: -> { arkose_labs_enabled?(user: nil) }
      before_action :restrict_registration, only: [:new, :create]
      before_action :ensure_can_remove_self, only: [:destroy]
      before_action :verify_arkose_labs_challenge!, only: :create
      before_action :check_seats, only: :create
    end

    override :new
    def new
      super

      ::Gitlab::Tracking.event(
        self.class.name,
        'render_registration_page',
        label: preregistration_tracking_label
      )
    end

    override :destroy
    def destroy
      unless allow_account_deletion?
        redirect_to profile_account_path, status: :see_other, alert: s_('Profiles|Account deletion is not allowed.')
        return
      end

      super
    end

    private

    def verify_arkose_labs_challenge!
      start_time = current_monotonic_time
      return if verify_arkose_labs_token

      flash[:alert] =
        s_('Session|There was a error loading the user verification challenge. Refresh to try again.')

      render action: 'new'
    ensure
      store_duration(:verify_arkose_labs_challenge!, start_time)
    end

    def restrict_registration
      start_time = current_monotonic_time
      return unless restricted_country?(request.env['HTTP_CF_IPCOUNTRY'])
      return if allow_invited_user?

      member&.destroy
      redirect_to restricted_signup_identity_verification_path
    ensure
      store_duration(:ee_restrict_registration, start_time)
    end

    def check_seats
      start_time = current_monotonic_time
      return unless ::GitlabSubscriptions::MemberManagement::BlockSeatOverages.block_seat_overages_for_self_managed?

      email = Array.wrap(sign_up_params[:email])
      return if ::GitlabSubscriptions::MemberManagement::BlockSeatOverages
        .seats_available_for_self_managed?(email, ::Gitlab::Access::GUEST, nil)

      flash[:alert] =
        s_('Registration|There are no seats left on your GitLab instance. Please contact your GitLab administrator.')

      render action: 'new'
    ensure
      store_duration(:ee_check_seats, start_time)
    end

    def allow_invited_user?
      return false unless invite_root_namespace

      invite_root_namespace.paid? || invite_root_namespace.trial?
    end

    def invite_root_namespace
      member&.source&.root_ancestor
    end
    strong_memoize_attr :invite_root_namespace

    def member
      member_id = session[:originating_member_id]
      return unless member_id

      ::Member.find_by_id(member_id)
    end
    strong_memoize_attr :member

    def exempt_paid_namespace_invitee_from_identity_verification(user)
      return unless identity_verification_enabled?
      return unless invite_root_namespace&.has_subscription?

      id_check_for_oss = ::Feature.enabled?(:id_check_for_oss, user)
      return unless invite_root_namespace&.actual_plan&.paid_excluding_trials?(exclude_oss: id_check_for_oss)

      user.add_identity_verification_exemption('invited to paid namespace')
    end

    override :after_successful_create_hook
    def after_successful_create_hook(user)
      # The order matters here as the arkose call needs to come before the devise action happens.
      # In that devise create action the user.active_for_authentication? call needs to return false so that
      # RegistrationsController#after_inactive_sign_up_path_for is correctly called with the custom_attributes
      # that are added by this action so that the IdentityVerifiable module observation of them is correct.
      # Identity Verification feature specs cover this ordering.

      store_duration(:ee_record_arkose_data) { record_arkose_data(user) }

      # calling this before super since originating_member_id will be cleared from the session when super is called
      store_duration(:ee_exempt_paid_namespace_invitee_from_identity_verification) do
        exempt_paid_namespace_invitee_from_identity_verification(user)
      end

      super

      store_duration(:ee_send_custom_confirmation_instructions) { send_custom_confirmation_instructions }

      store_duration(:ee_user_assume_high_risk_if_phone_verification_limit_exceeded!) do
        user.assume_high_risk_if_phone_verification_limit_exceeded!
      end

      store_duration(:ee_onboarding_status_create_service_instantiate) do
        ::Onboarding::StatusCreateService
        .new(onboarding_status_params, session['user_return_to'], resource, onboarding_first_step_path(user)).execute
        clear_memoization(:onboarding_status_presenter) # clear since registration_type is now set
      end

      store_duration(:ee_log_audit_event) { log_audit_event(user) }

      # This must come after user has been onboarding to properly detect the label from the onboarded user.

      store_duration(:ee_successfull_submitted_form_event) do
        ::Gitlab::Tracking.event(
          self.class.name,
          'successfully_submitted_form',
          label: onboarding_status_presenter.tracking_label,
          user: user
        )
      end
    end

    override :onboarding_status_params
    def onboarding_status_params
      base_params = params.permit(:invite_email, *::Onboarding::StatusPresenter::GLM_PARAMS)

      return base_params.to_h.deep_symbolize_keys if request.get?

      params.require(:user)
            .permit(:onboarding_status_email_opt_in).merge(base_params).to_h.deep_symbolize_keys
    end

    override :set_resource_fields
    def set_resource_fields
      super

      custom_confirmation_instructions_service.set_token(save: false)
    end

    override :identity_verification_enabled?
    def identity_verification_enabled?
      resource.signup_identity_verification_enabled?
    end

    override :identity_verification_redirect_path
    def identity_verification_redirect_path
      signup_identity_verification_path
    end

    def send_custom_confirmation_instructions
      return unless identity_verification_enabled?

      custom_confirmation_instructions_service.send_instructions
    end

    def custom_confirmation_instructions_service
      ::Users::EmailVerification::SendCustomConfirmationInstructionsService.new(resource)
    end
    strong_memoize_attr :custom_confirmation_instructions_service

    def ensure_can_remove_self
      unless current_user&.can_remove_self?
        redirect_to profile_account_path,
          status: :see_other,
          alert: s_('Profiles|Account could not be deleted. GitLab was unable to verify your identity.')
      end
    end

    def log_audit_event(user)
      ::Gitlab::Audit::Auditor.audit({
        name: "registration_created",
        author: user,
        scope: user,
        target: user,
        target_details: user.username,
        message: _("Instance access request"),
        additional_details: {
          registration_details: user.registration_audit_details
        }
      })
    end

    def record_arkose_data(user)
      return unless arkose_labs_enabled?(user: user)
      return unless arkose_labs_verify_response

      track_arkose_challenge_result

      Arkose::RecordUserDataService.new(
        response: arkose_labs_verify_response,
        user: user
      ).execute
    end

    override :arkose_labs_enabled?
    def arkose_labs_enabled?(user:)
      ::AntiAbuse::IdentityVerification::Settings.arkose_enabled?(user: user, user_agent: request.user_agent)
    end

    override :preregistration_tracking_label
    def preregistration_tracking_label
      onboarding_status_presenter.preregistration_tracking_label
    end

    override :track_error
    def track_error(_new_user)
      super
      track_invalid_user_error(preregistration_tracking_label)
    end

    override :sign_up_params
    def sign_up_params
      start_time = current_monotonic_time
      data = super

      return super unless ::Onboarding.enabled? && data.key?(:onboarding_status_email_opt_in)

      # We want to say that if for some reason the param is nil, then we can't
      # be certain the user was ever shown this option so we should default to false to follow opt in guidelines.
      data[:onboarding_status_email_opt_in] =
        ::Gitlab::Utils.to_boolean(data[:onboarding_status_email_opt_in], default: false)
      store_duration(:ee_sign_up_params_ee, start_time)
      data
    end

    override :sign_up_params_attributes
    def sign_up_params_attributes
      return super unless ::Onboarding.enabled?

      super + [:onboarding_status_email_opt_in]
    end

    def allow_account_deletion?
      !License.feature_available?(:disable_deleting_account_for_users) ||
        ::Gitlab::CurrentSettings.allow_account_deletion?
    end

    def username
      sign_up_params[:username]
    end
  end
end
