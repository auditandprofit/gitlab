# frozen_string_literal: true

module GitlabSubscriptions
  module DuoEnterpriseAlert
    class FreeComponent < BaseComponent
      private

      def render?
        namespace.free_plan? && GitlabSubscriptions::DuoEnterprise.no_add_on_purchase_for_namespace?(namespace)
      end

      def body
        [
          s_('BillingPlans|Start an Ultimate trial with GitLab Duo Enterprise to ' \
            'try the complete set of features from GitLab. GitLab Duo Enterprise ' \
            'gives you access to the full product offering from GitLab, including ' \
            'AI-native features. You can try it for free, no credit card required.')
        ]
      end
    end
  end
end
