# frozen_string_literal: true

module Billing
  class PlanComponent < ViewComponent::Base
    # @param [Namespace or Group] namespace
    # @param [Hashie::Mash] plans_data
    # @param [Hashie::Mash] current_plan

    def initialize(plans_data:, namespace:, current_plan:)
      @plan = plans_data.find { |plan| plan['code'] == plan_name }
      @namespace = namespace
      @current_plan = current_plan
    end

    private

    attr_reader :plan, :namespace, :current_plan

    delegate :number_to_plan_currency, :plan_purchase_url, :sprite_icon, to: :helpers

    def show_upgrade_button?
      raise NoMethodError, 'Missing show_upgrade_button? implementation'
    end

    def show_learn_more_link?
      raise NoMethodError, 'Missing show_learn_more_link? implementation'
    end

    # JH needs to override the symbol
    def currency_symbol
      '$'
    end

    def card_testid
      "plan-card-#{plan_name}"
    end

    def header_classes
      "gl-text-center gl-border-none gl-p-0 gl-leading-28 #{per_plan_header_classes}"
    end

    def per_plan_header_classes
      # The inheriting class may override this
    end

    def header_text
      # The inheriting class may override this
    end

    def body_classes
      "#{base_body_classes} gl-rounded-br-base gl-rounded-bl-base"
    end

    def base_body_classes
      'gl-bg-subtle gl-p-7 gl-border'
    end

    def footer_classes
      "gl-border-none gl-bg-transparent gl-px-0"
    end

    def name
      raise NoMethodError, 'Missing name implementation'
    end

    def plan_name
      raise NoMethodError, 'Missing plan_name implementation'
    end

    def elevator_pitch
      raise NoMethodError, 'Missing elevator_pitch implementation'
    end

    def features_elevator_pitch
      raise NoMethodError, 'Missing features_elevator_pitch implementation'
    end

    def learn_more_text
      # The inheriting class may override this
    end

    def learn_more_url
      promo_pricing_url(path: "/#{plan_name}")
    end

    def price_per_month
      number_to_currency(plan.price_per_month, unit: '', strip_insignificant_zeros: true)
    end

    def pricing_text
      s_('BillingPlans|Billed annually at %{price_per_year} USD') % { price_per_year: price_per_year }
    end

    def price_per_year
      number_to_plan_currency(plan.price_per_year)
    end

    def cta_category
      # The inheriting class may override this
    end

    def cta_text
      # The inheriting class may override this
    end

    def cta_url
      plan_purchase_url(namespace, plan)
    end

    def cta_data
      {
        track_action: 'click_button',
        track_label: 'plan_cta',
        track_property: plan_name,
        testid: "upgrade-to-#{plan_name}"
      }
    end

    def features
      raise NoMethodError, 'Missing features implementation'
    end
  end
end

Billing::PlanComponent.prepend_mod
