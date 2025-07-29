# frozen_string_literal: true

module EE
  module Projects
    module WorkItemsController
      extend ActiveSupport::Concern

      prepended do
        before_action only: [:show, :index] do
          push_licensed_feature(:generate_description, project) if can?(current_user, :generate_description, project)
        end
        before_action do
          push_force_frontend_feature_flag(:okrs_mvc, !!project&.okrs_mvc_feature_flag_enabled?)
          push_force_frontend_feature_flag(:okr_automatic_rollups, !!project&.okr_automatic_rollups_enabled?)
        end
        before_action :set_application_context!, only: [:show]
      end

      private

      def set_application_context!
        ::Gitlab::ApplicationContext.push(ai_resource: issuable.try(:to_global_id))
      end
    end
  end
end
