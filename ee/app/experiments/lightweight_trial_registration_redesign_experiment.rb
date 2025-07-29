# frozen_string_literal: true

class LightweightTrialRegistrationRedesignExperiment < ApplicationExperiment
  control
  variant(:candidate)

  exclude :non_new_trial_registrations

  private

  def control_behavior; end
  def candidate_behavior; end

  def non_new_trial_registrations
    actor = context.try(:actor)
    return false unless actor # not created user yet
    return false if actor.is_a? String # not logged in yet - cookie signature

    registration_type = actor.onboarding_status_initial_registration_type
    registration_type.present? && registration_type != 'trial'
  end
end
