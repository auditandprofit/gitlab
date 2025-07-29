# frozen_string_literal: true

module EE
  module Onboarding
    module StatusPresenter
      extend ::Gitlab::Utils::Override

      GLM_PARAMS = [:glm_source, :glm_content].freeze
      PASSED_THROUGH_PARAMS = [:jobs_to_be_done_other].freeze

      attr_reader :registration_type, :user_return_to

      # string delegations
      delegate :tracking_label, to: :registration_type
      # translation delegations
      delegate :setup_for_company_label_text, to: :registration_type
      delegate :setup_for_company_help_text, to: :registration_type
      # predicate delegations
      delegate :redirect_to_company_form?, :show_company_form_side_column?, to: :registration_type
      delegate :show_joining_project?, :hide_setup_for_company_field?, to: :registration_type
      delegate :read_from_stored_user_location?, :preserve_stored_location?, to: :registration_type
      delegate :learn_gitlab_redesign?, :show_company_form_footer?, to: :registration_type

      module ClassMethods
        extend ::Gitlab::Utils::Override

        def glm_tracking_params(params)
          params.permit(*GLM_PARAMS)
        end

        def glm_tracking_attributes(params)
          # Converting to a normal hash here to get more predictable
          # behavior with the merge and basic hash behavior as we
          # want to only think about it as a hash here.
          glm_tracking_params(params).to_h
        end

        def passed_through_params(params)
          params.permit(*PASSED_THROUGH_PARAMS)
        end

        override :registration_path_params
        def registration_path_params(params:)
          return super unless ::Onboarding.enabled?

          glm_tracking_attributes(params)
        end
      end

      def self.prepended(base)
        base.singleton_class.prepend(ClassMethods)
      end

      def initialize(*)
        super

        @registration_type = ::Onboarding::UserStatus.new(user).registration_type
      end

      def welcome_submit_button_text
        base_value = registration_type.welcome_submit_button_text

        return base_value if registration_type.ignore_oauth_in_welcome_submit_text?
        return _('Get started!') if oauth?

        # free, trial if not in oauth
        base_value
      end

      def continue_full_onboarding?
        registration_type.continue_full_onboarding? && !oauth? && ::Onboarding.enabled?
      end

      def joining_a_project?
        ::Gitlab::Utils.to_boolean(user.onboarding_status_joining_project, default: false)
      end

      def email_opt_in?
        ::Gitlab::Utils.to_boolean(params[:onboarding_status_email_opt_in], default: true)
      end

      def convert_to_automatic_trial?
        return false unless registration_type.convert_to_automatic_trial?

        setup_for_company?
      end

      def preregistration_tracking_label
        # Trial registrations do not call this right now, so we'll omit it here from consideration.
        return ::Onboarding::InviteRegistration.tracking_label if params[:invite_email]
        return ::Onboarding::SubscriptionRegistration.tracking_label if subscription_from_stored_location?

        ::Onboarding::FreeRegistration.tracking_label
      end

      def setup_for_company?
        ::Gitlab::Utils.to_boolean(params[:onboarding_status_setup_for_company], default: false)
      end

      override :registration_omniauth_params
      def registration_omniauth_params
        return super unless ::Onboarding.enabled?

        # We don't have controller params here, so we need to slice instead of permit
        super
          .merge(params.slice(*GLM_PARAMS))
          .merge(onboarding_status_email_opt_in: email_opt_in?)
      end

      def trial_registration_omniauth_params
        registration_omniauth_params.merge(trial: true)
      end

      private

      attr_reader :params, :onboarding_user_status

      def oauth?
        # During authorization for oauth, we want to allow it to finish.
        return false unless base_stored_user_location_path.present?

        base_stored_user_location_path == ::Gitlab::Routing.url_helpers.oauth_authorization_path
      end

      def subscription_from_stored_location?
        base_stored_user_location_path == ::Gitlab::Routing.url_helpers.new_subscriptions_path
      end

      def base_stored_user_location_path
        return unless user_return_to

        URI.parse(user_return_to).path
      end
    end
  end
end
