# frozen_string_literal: true

module GitlabSubscriptions
  module DuoEnterpriseAlert
    class UltimateComponent < BaseComponent
      extend ::Gitlab::Utils::Override

      private

      def render?
        namespace.ultimate_plan? && GitlabSubscriptions::DuoEnterprise.no_add_on_purchase_for_namespace?(namespace)
      end

      def title
        s_('BillingPlans|Introducing GitLab Duo Enterprise')
      end

      def body
        [
          s_('BillingPlans|Start a GitLab Duo Enterprise trial to try all end-to-end ' \
            'AI capabilities from GitLab. You can try it for free for 60 days, no ' \
            'credit card required.')
        ]
      end

      override :primary_link
      def primary_link
        new_trials_duo_enterprise_path(namespace_id: namespace.id)
      end

      override :primary_tracking_label
      def primary_tracking_label
        'duo_enterprise_trial'
      end

      override :primary_cta
      def primary_cta
        s_('BillingPlans|Start a free GitLab Duo Enterprise Trial')
      end
    end
  end
end
