# frozen_string_literal: true

module EE
  module Onboarding
    module Redirectable
      extend ::Gitlab::Utils::Override

      private

      def onboarding_first_step_path(user)
        return unless ::Onboarding.enabled?

        # rubocop:disable Cop/ExperimentsTestCoverage -- covered in redirectable_shared_examples.rb
        experiment(:lightweight_trial_registration_redesign, actor: user) do |e|
          e.control { users_sign_up_welcome_path }
          e.candidate { new_users_sign_up_trial_welcome_path }
        end.run
        # rubocop:enable Cop/ExperimentsTestCoverage
      end

      override :after_sign_up_path
      def after_sign_up_path(user)
        if ::Onboarding.enabled?
          onboarding_first_step_path(user)
        else
          super
        end
      end
    end
  end
end
