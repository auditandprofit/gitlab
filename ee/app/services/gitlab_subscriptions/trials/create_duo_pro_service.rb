# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class CreateDuoProService < ::GitlabSubscriptions::Trials::BaseCreateAddOnService
      private

      def apply_trial_service_class
        GitlabSubscriptions::Trials::ApplyDuoProService
      end

      def namespaces_eligible_for_trial
        Users::AddOnTrialEligibleNamespacesFinder.new(user, add_on: :duo).execute
      end

      override :product_interaction
      def product_interaction
        'duo_pro_trial'
      end

      override :trial_user_params
      def trial_user_params
        # We override here as we use a general add on lead service currently
        # GitlabSubscriptions::Trials::CreateAddOnLeadService.
        params = super
        params[:add_on_name] = 'code_suggestions'

        params
      end

      override :tracking_prefix
      def tracking_prefix
        'duo_pro_'
      end
    end
  end
end
