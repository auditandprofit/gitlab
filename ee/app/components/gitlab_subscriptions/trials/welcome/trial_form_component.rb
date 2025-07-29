# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    module Welcome
      class TrialFormComponent < ViewComponent::Base
        def initialize(**kwargs)
          @user = kwargs[:user]
          @params = kwargs[:params]
        end

        private

        attr_reader :user, :params

        def form_data
          ::Gitlab::Json.generate(
            {
              userData: user_data,
              submitPath: submit_path,
              gtmSubmitEventLabel: 'saasTrialSubmit',
              namespaceId: params[:namespace_id],
              serverValidations: params[:errors] || {}
            }
          )
        end

        def user_data
          {
            firstName: params[:first_name] || user.first_name,
            lastName: params[:last_name] || user.last_name,
            emailDomain: user.email_domain,
            companyName: params[:company_name] || user.user_detail_organization,
            country: params[:country] || '',
            state: params[:state] || '',
            groupName: params[:group_name] || '',
            projectName: params[:project_name] || ''
          }
        end

        def submit_path
          users_sign_up_trial_welcome_path(**params.slice(*::Onboarding::StatusPresenter::GLM_PARAMS))
        end
      end
    end
  end
end
