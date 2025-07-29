# frozen_string_literal: true

module Onboarding
  class InviteRegistration
    PRODUCT_INTERACTION = 'Invited User'
    private_constant :PRODUCT_INTERACTION
    TRACKING_LABEL = 'invite_registration'
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
      _('Get started!')
    end

    def self.setup_for_company_help_text
      nil
    end

    # predicate methods

    def self.redirect_to_company_form?
      false
    end

    def self.eligible_for_iterable_trigger?
      true
    end

    def self.include_existing_plan_for_iterable?
      true
    end

    def self.continue_full_onboarding?
      false
    end

    def self.convert_to_automatic_trial?
      false
    end

    def self.show_joining_project?
      false
    end

    def self.hide_setup_for_company_field?
      true
    end

    def self.read_from_stored_user_location?
      false
    end

    def self.preserve_stored_location?
      false
    end

    def self.ignore_oauth_in_welcome_submit_text?
      true
    end
  end
end
