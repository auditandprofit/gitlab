# frozen_string_literal: true

module Billing
  class UltimatePlanComponent < Billing::PlanComponent
    private

    def plan_name
      ::Plan::ULTIMATE
    end

    def name
      s_('BillingPlans|Ultimate')
    end

    def learn_more_text
      s_('BillingPlans|Learn more about Ultimate')
    end

    def show_upgrade_button?
      true
    end

    def show_learn_more_link?
      true
    end

    def body_classes
      "#{super} gl-rounded-tr-base gl-rounded-tl-base"
    end

    def cta_category
      'secondary'
    end

    def cta_text
      s_('BillingPlans|Upgrade to Ultimate')
    end

    def elevator_pitch
      s_('BillingPlans|For enterprises looking to deliver software faster')
    end

    def features_elevator_pitch
      s_('BillingPlans|Everything from Premium, plus:')
    end

    def features
      [
        *Billing::DuoCoreCommon.features,
        s_('BillingPlans|Suggested Reviewers'),
        s_('BillingPlans|Dynamic Application Security Testing'),
        s_('BillingPlans|Security Dashboards'),
        s_('BillingPlans|Vulnerability Management'),
        s_('BillingPlans|Dependency Scanning'),
        s_('BillingPlans|Container Scanning'),
        s_('BillingPlans|Static Application Security Testing'),
        s_('BillingPlans|Multi-Level Epics'),
        s_('BillingPlans|Portfolio Management'),
        s_('BillingPlans|Custom Roles'),
        s_('BillingPlans|Value Stream Management'),
        s_('BillingPlans|50,000 CI/CD minutes per month'),
        s_('BillingPlans|Free guest users')
      ]
    end
  end
end
