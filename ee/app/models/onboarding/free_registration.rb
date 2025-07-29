# frozen_string_literal: true

module Onboarding
  class FreeRegistration
    PRODUCT_INTERACTION = 'Personal SaaS Registration'
    private_constant :PRODUCT_INTERACTION
    TRACKING_LABEL = 'free_registration'
    private_constant :TRACKING_LABEL

    # string methods

    def self.tracking_label
      TRACKING_LABEL
    end

    def self.product_interaction
      PRODUCT_INTERACTION
    end

    # internalization methods

    def self.welcome_submit_button_text
      _('Continue')
    end

    def self.setup_for_company_label_text
      _('Who will be using GitLab?')
    end

    def self.setup_for_company_help_text
      _('Enables a free Ultimate + GitLab Duo Enterprise trial when you create a new project.')
    end

    # predicate methods

    def self.learn_gitlab_redesign?
      false
    end

    def self.redirect_to_company_form?
      false
    end

    def self.eligible_for_iterable_trigger?
      true
    end

    def self.include_existing_plan_for_iterable?
      false
    end

    def self.continue_full_onboarding?
      true
    end

    def self.convert_to_automatic_trial?
      true
    end

    def self.show_joining_project?
      true
    end

    def self.hide_setup_for_company_field?
      false
    end

    def self.apply_trial?
      false
    end

    def self.read_from_stored_user_location?
      false
    end

    def self.preserve_stored_location?
      false
    end

    def self.ignore_oauth_in_welcome_submit_text?
      false
    end
  end
end
