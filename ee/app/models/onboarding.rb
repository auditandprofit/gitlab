# frozen_string_literal: true

module Onboarding
  StepUrlError = Class.new(StandardError)

  REGISTRATION_TYPE = {
    free: 'free',
    trial: 'trial',
    invite: 'invite',
    subscription: 'subscription'
  }.freeze

  def self.enabled?
    ::Gitlab::Saas.feature_available?(:onboarding)
  end

  def self.user_onboarding_in_progress?(user, use_cache: false)
    return false unless user.present?
    return false unless enabled?

    return user.onboarding_in_progress? unless use_cache

    if user.onboarding_in_progress?
      # read from Rails cache if present
      cached_result = fetch_onboarding_in_progress(user)

      return cached_result unless cached_result.nil?
    end

    user.onboarding_in_progress?
  end

  def self.fetch_onboarding_in_progress(user)
    Rails.cache.fetch("user_onboarding_in_progress:#{user.id}")
  end

  def self.cache_onboarding_in_progress(user)
    Rails.cache.write("user_onboarding_in_progress:#{user.id}", user.onboarding_in_progress)
  end

  def self.completed_welcome_step?(user)
    !user.onboarding_status_setup_for_company.nil?
  end

  def self.add_on_seat_assignment_iterable_params(user, product_interaction, namespace)
    {
      first_name: user.first_name,
      last_name: user.last_name,
      work_email: user.email,
      namespace_id: namespace.id,
      product_interaction: product_interaction,
      existing_plan: namespace.actual_plan_name,
      opt_in: user.onboarding_status_email_opt_in,
      preferred_language: ::Gitlab::I18n.trimmed_language_name(user.preferred_language)
    }.stringify_keys
  end
end
