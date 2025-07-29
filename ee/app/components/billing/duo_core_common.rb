# frozen_string_literal: true

module Billing
  module DuoCoreCommon
    def self.features
      [
        s_('BillingPlans|AI Chat in the IDE'),
        s_('BillingPlans|AI Code Suggestions in the IDE')
      ]
    end
  end
end
