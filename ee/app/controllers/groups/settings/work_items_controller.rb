# frozen_string_literal: true

module Groups
  module Settings
    class WorkItemsController < Groups::ApplicationController
      layout 'group_settings'

      before_action :check_feature_availability
      before_action :authorize_admin_work_item_settings

      feature_category :team_planning
      urgency :low

      before_action do
        push_frontend_feature_flag(:work_item_status_feature_flag, group)
        push_frontend_feature_flag(:work_item_status_mvc2, group)
      end

      def show; end

      private

      def check_feature_availability
        render_404 unless group.licensed_feature_available?(:custom_fields) || group.work_item_status_feature_available?
      end

      def authorize_admin_work_item_settings
        render_404 unless can?(current_user, :admin_custom_field,
          group) || can?(current_user, :admin_work_item, group)
      end
    end
  end
end
