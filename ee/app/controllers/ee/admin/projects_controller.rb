# frozen_string_literal: true

module EE
  module Admin
    module ProjectsController
      extend ActiveSupport::Concern

      prepended do
        authorize! :read_admin_projects, only: %i[index show]

        before_action :limited_actions_message!, only: :show
      end
    end
  end
end
