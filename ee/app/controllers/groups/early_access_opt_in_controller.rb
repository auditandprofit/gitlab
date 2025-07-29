# frozen_string_literal: true

module Groups
  class EarlyAccessOptInController < Groups::ApplicationController
    layout 'minimal'

    before_action :authorize_admin_group!

    feature_category :groups_and_projects
    urgency :low

    def show; end

    def create
      ::Users::JoinEarlyAccessProgramService.new(current_user).execute

      redirect_to edit_group_path(@group)
      flash[:success] = _(
        'You have been enrolled in the Early Access Program. ' \
          'Thank you for helping make GitLab better. ' \
          'You will receive an email with more details about the program.'
      )
    end
  end
end
