# frozen_string_literal: true

module Projects
  module Settings
    class AnalyticsController < Projects::ApplicationController
      layout 'project_settings'
      feature_category :product_analytics

      before_action :authorize_analytics_settings!

      def update
        params_to_update = update_params.to_h
        if update_params[:project_setting_attributes].present?
          # clear instrumentation key since old one is not valid anymore
          # clear instrumentation key even if product_analytics_configurator_connection_string isn't provided
          # an empty product_analytics_configurator_connection_string can mean user is deleting BYOC product analytics.
          # a new instrumentation key will be set during stack initialization
          params_to_update.deep_merge!({ project_setting_attributes: { product_analytics_instrumentation_key: nil } })
        end

        ::Projects::UpdateService.new(project, current_user, params_to_update).tap do |service|
          result = service.execute
          if result[:status] == :success
            flash[:toast] =
              format(s_("Analytics|Analytics settings for '%{project_name}' were successfully updated."),
                project_name: project.name)

            redirect_to project_settings_analytics_path(project)
          else
            redirect_to project_settings_analytics_path(project), alert: result[:message]
          end
        end
      end

      private

      def update_params
        params.require(:project).permit(*permitted_project_params)
      end

      def permitted_project_params
        [
          project_setting_attributes: [
            :product_analytics_configurator_connection_string, :product_analytics_data_collector_host,
            :cube_api_base_url, :cube_api_key
          ],
          analytics_dashboards_pointer_attributes: [:target_project_id, :id]
        ]
      end

      def authorize_analytics_settings!
        access_denied! unless product_analytics_settings_allowed?(project)
      end
    end
  end
end
