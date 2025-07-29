# frozen_string_literal: true

module Projects
  class GetStartedController < Projects::ApplicationController
    include ::Onboarding::SetRedirect

    before_action :verify_onboarding_enabled!
    before_action :authenticate_user!
    before_action :verify_available!

    helper_method :onboarding_progress

    feature_category :onboarding
    urgency :low

    def show
      experiment(:lightweight_trial_registration_redesign, actor: current_user).track(:render_get_started)

      @get_started_presenter = ::Onboarding::GetStartedPresenter.new(current_user, project, onboarding_progress)
    end

    def end_tutorial
      if onboarding_progress.update(ended_at: Time.current)
        redirect_to project_path(project)
        flash[:success] = s_("GetStarted|You've ended the tutorial.")
      else
        flash[:danger] =
          s_("GetStarted|There was a problem trying to end the tutorial. Please try again.")
      end
    end

    private

    def onboarding_progress
      # We only want to observe first level projects.
      # We do not care about any of their subgroup projects.
      # See https://gitlab.com/gitlab-org/gitlab/-/issues/537653#note_2478488770
      @onboarding_progress ||= ::Onboarding::Progress.find_by_namespace_id!(@project.namespace)
    end

    def verify_available!
      access_denied! unless ::Onboarding::LearnGitlab.available?(project.namespace, current_user)
    end
  end
end
