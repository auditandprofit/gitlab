# frozen_string_literal: true

module Onboarding
  class SubscriptionRegistration
    TRACKING_LABEL = 'subscription_registration'
    private_constant :TRACKING_LABEL

    # string methods

    def self.tracking_label
      TRACKING_LABEL
    end

    # internalization methods

    def self.welcome_submit_button_text
      _('Continue')
    end

    def self.setup_for_company_label_text
      _('Who will be using this GitLab subscription?')
    end

    def self.setup_for_company_help_text
      nil
    end

    # predicate methods

    def self.redirect_to_company_form?
      false
    end

    def self.eligible_for_iterable_trigger?
      false
    end

    def self.continue_full_onboarding?
      false
    end

    def self.convert_to_automatic_trial?
      false
    end

    def self.show_joining_project?
      true
    end

    def self.hide_setup_for_company_field?
      false
    end

    def self.read_from_stored_user_location?
      true
    end

    def self.preserve_stored_location?
      true
    end

    def self.ignore_oauth_in_welcome_submit_text?
      true
    end
  end
end
