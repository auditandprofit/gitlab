# frozen_string_literal: true

module Users
  class SignupService < BaseService
    def initialize(current_user, user_return_to:, params: {})
      @user = current_user
      @user_return_to = user_return_to
      @params = params.dup
      set_onboarding_user_status
    end

    def execute
      log_params if ::Feature.enabled?(:stop_welcome_redirection, user)
      assign_attributes
      inject_validators

      if @user.save
        reset_onboarding_user_status # needed in case registration_type is changed on update
        trigger_iterable_creation if onboarding_user_status.eligible_for_iterable_trigger?

        ServiceResponse.success(payload: payload)
      else
        user_errors = user.errors.full_messages.join('. ')

        msg = <<~MSG.squish
          #{self.class.name}: Could not save user with errors: #{user_errors} and
          onboarding_status: #{user.onboarding_status}
        MSG

        log_error(msg)

        ServiceResponse.error(message: user_errors, payload: payload)
      end
    end

    private

    attr_reader :user, :user_return_to, :onboarding_user_status

    def log_params
      Gitlab::AppLogger.info(
        message: "#{self.class.name}: user_return_to: #{user_return_to}, params: #{params.to_json}",
        user_id: user.id
      )
    end

    def payload
      { user: user }
    end

    def set_onboarding_user_status
      @onboarding_user_status = Onboarding::UserStatus.new(user)
    end
    alias_method :reset_onboarding_user_status, :set_onboarding_user_status

    def trigger_iterable_creation
      ::Onboarding::CreateIterableTriggerWorker.perform_async(iterable_params.stringify_keys)
    end

    def iterable_params
      {
        provider: 'gitlab',
        work_email: user.email,
        uid: user.id,
        comment: params[:jobs_to_be_done_other],
        jtbd: user.onboarding_status_registration_objective_name,
        product_interaction: onboarding_user_status.product_interaction,
        opt_in: user.onboarding_status_email_opt_in,
        preferred_language: ::Gitlab::I18n.trimmed_language_name(user.preferred_language),
        setup_for_company: user.onboarding_status_setup_for_company,
        role: user.onboarding_status_role_name
      }.merge(onboarding_user_status.existing_plan)
    end

    def assign_attributes
      @user.assign_attributes(user_params) unless user_params.empty?
    end

    def user_params
      params.except(:jobs_to_be_done_other)
    end

    def inject_validators
      class << @user.user_detail
        validates :onboarding_status_role, presence: true
        validates :onboarding_status_setup_for_company, inclusion: { in: [true, false], message: :blank }
      end
    end
  end
end
