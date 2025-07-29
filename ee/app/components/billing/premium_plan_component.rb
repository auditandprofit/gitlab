# frozen_string_literal: true

module Billing
  class PremiumPlanComponent < Billing::PlanComponent
    private

    def plan_name
      ::Plan::PREMIUM
    end

    def name
      s_('BillingPlans|Premium')
    end

    def learn_more_text
      s_('BillingPlans|Learn more about Premium')
    end

    def show_upgrade_button?
      true
    end

    def show_learn_more_link?
      true
    end

    def per_plan_header_classes
      'gl-text-white gl-bg-purple-500'
    end

    def header_text
      s_('BillingPlans|Recommended')
    end

    def body_classes
      "#{super} gl-border-purple-500!"
    end

    def cta_category
      'primary'
    end

    def cta_text
      s_('BillingPlans|Upgrade to Premium')
    end

    def elevator_pitch
      s_('BillingPlans|For scaling organizations and multi-team usage')
    end

    def features_elevator_pitch
      s_('BillingPlans|Everything from Free, plus:')
    end

    def features
      [
        *Billing::DuoCoreCommon.features,
        s_('BillingPlans|Code Ownership and Protected Branches'),
        s_('BillingPlans|Merge Request Approval Rules'),
        s_('BillingPlans|Enterprise Agile Planning'),
        s_('BillingPlans|Advanced CI/CD'),
        s_('BillingPlans|Support'),
        s_('BillingPlans|Enterprise User and Incident Management'),
        s_('BillingPlans|10,000 CI/CD minutes per month')
      ]
    end
  end
end
