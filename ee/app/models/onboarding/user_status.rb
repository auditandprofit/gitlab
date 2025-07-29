# frozen_string_literal: true

module Onboarding
  class UserStatus
    REGISTRATION_KLASSES = {
      ::Onboarding::REGISTRATION_TYPE[:free] => ::Onboarding::FreeRegistration,
      ::Onboarding::REGISTRATION_TYPE[:trial] => ::Onboarding::TrialRegistration,
      ::Onboarding::REGISTRATION_TYPE[:invite] => ::Onboarding::InviteRegistration,
      ::Onboarding::REGISTRATION_TYPE[:subscription] => ::Onboarding::SubscriptionRegistration
    }.freeze
    private_constant :REGISTRATION_KLASSES

    attr_reader :registration_type

    # string delegations
    delegate :product_interaction, to: :registration_type
    # predicate delegations
    delegate :apply_trial?, :eligible_for_iterable_trigger?, to: :registration_type

    def initialize(user)
      @user = user

      @registration_type = calculate_registration_type_klass
    end

    def existing_plan
      (registration_type.include_existing_plan_for_iterable? &&
        plan_name_from_invited_source&.then { |plan| { existing_plan: plan } }) || {}
    end

    private

    attr_reader :user

    def plan_name_from_invited_source
      user.members.last&.source&.root_ancestor&.actual_plan_name
    end

    def calculate_registration_type_klass
      return ::Onboarding::AutomaticTrialRegistration if automatic_trial?

      REGISTRATION_KLASSES.fetch(user&.onboarding_status_registration_type, ::Onboarding::FreeRegistration)
    end

    def automatic_trial?
      trial_registration? && !initial_trial?
    end

    def trial_registration?
      user&.onboarding_status_registration_type == registration_type_trial
    end

    def initial_trial?
      user.onboarding_status_initial_registration_type == registration_type_trial
    end

    def registration_type_trial
      REGISTRATION_TYPE[:trial]
    end
  end
end
