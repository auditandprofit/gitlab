# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class ApplyTrialService < BaseApplyTrialService
      def valid_to_generate_trial?
        namespace.present? && GitlabSubscriptions::Trials.namespace_eligible?(namespace)
      end

      private

      def execute_trial_request
        trial_user_information.merge!(add_on_name: 'duo_enterprise', trial_type: trial_type)

        client.generate_trial(uid: uid, trial_user: trial_user_information)
      end

      def trial_type
        if namespace.free_plan?
          GitlabSubscriptions::Trials::FREE_TRIAL_TYPE
        else
          GitlabSubscriptions::Trials::PREMIUM_TRIAL_TYPE
        end
      end

      def add_on_purchase_finder
        GitlabSubscriptions::Trials::DuoEnterprise
      end

      def after_success_hook
        ::Onboarding::ProgressService.new(namespace).execute(action: :trial_started)
      end
    end
  end
end
