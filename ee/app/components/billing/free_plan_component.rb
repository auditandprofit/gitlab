# frozen_string_literal: true

module Billing
  class FreePlanComponent < Billing::PlanComponent
    private

    def plan_name
      ::Plan::FREE
    end

    def name
      s_('BillingPlans|Free')
    end

    def current_trial?
      current_plan.code == ::Plan::ULTIMATE_TRIAL
    end

    def show_upgrade_button?
      false
    end

    def show_learn_more_link?
      false
    end

    def header_classes
      return 'gl-border-none gl-p-0 gl-h-0!' if current_trial?

      super
    end

    def per_plan_header_classes
      'gl-bg-gray-100'
    end

    def header_text
      return if current_trial?

      s_('BillingPlans|Your current plan')
    end

    def body_classes
      return "#{base_body_classes} gl-rounded-base" if current_trial?

      super
    end

    def elevator_pitch
      s_('BillingPlans|Use GitLab for personal projects')
    end

    def pricing_text
      s_('BillingPlans|No credit card required')
    end

    def features_elevator_pitch
      s_('BillingPlans|Free forever features:')
    end

    def features
      [
        s_('BillingPlans|400 CI/CD minutes per month'),
        s_('BillingPlans|5 users per top-level group')
      ]
    end
  end
end
