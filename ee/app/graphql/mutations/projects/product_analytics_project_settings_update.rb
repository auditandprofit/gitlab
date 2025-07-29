# frozen_string_literal: true

module Mutations
  module Projects
    class ProductAnalyticsProjectSettingsUpdate < BaseMutation
      graphql_name 'ProductAnalyticsProjectSettingsUpdate'

      include FindsProject

      authorize :admin_project

      argument :full_path,
        GraphQL::Types::ID,
        required: true,
        description: 'Full path of the project the settings belong to.'

      argument :product_analytics_configurator_connection_string,
        GraphQL::Types::String,
        required: false,
        description: 'Connection string for the product analytics configurator.'

      argument :product_analytics_data_collector_host,
        GraphQL::Types::String,
        required: false,
        description: 'Host for the product analytics data collector.'

      argument :cube_api_base_url,
        GraphQL::Types::String,
        required: false,
        description: 'Base URL for the Cube API.'

      argument :cube_api_key,
        GraphQL::Types::String,
        required: false,
        description: 'API key for the Cube API.'

      field :product_analytics_configurator_connection_string,
        GraphQL::Types::String,
        null: true,
        description: 'Connection string for the product analytics configurator.'

      field :product_analytics_data_collector_host,
        GraphQL::Types::String,
        null: true,
        description: 'Host for the product analytics data collector.'

      field :cube_api_base_url,
        GraphQL::Types::String,
        null: true,
        description: 'Base URL for the Cube API.'

      field :cube_api_key,
        GraphQL::Types::String,
        null: true,
        description: 'API key for the Cube API.'

      def resolve(full_path:, **args)
        project = authorized_find!(full_path)
        raise raise_resource_not_available_error! unless allowed?(project)

        params_to_update = args.to_h
        if params_to_update[:product_analytics_configurator_connection_string].present?
          # clear instrumentation key since old one is not valid anymore
          # clear instrumentation key even if product_analytics_configurator_connection_string isn't provided
          # an empty product_analytics_configurator_connection_string can mean user is deleting BYOC product analytics.
          # a new instrumentation key will be set during stack initialization
          params_to_update[:product_analytics_instrumentation_key] = nil
        end

        ::Projects::UpdateService.new(project, current_user, { project_setting_attributes: params_to_update }).execute

        {
          product_analytics_configurator_connection_string:
            project.project_setting.product_analytics_configurator_connection_string,
          product_analytics_data_collector_host: project.project_setting.product_analytics_data_collector_host,
          cube_api_base_url: project.project_setting.cube_api_base_url,
          cube_api_key: project.project_setting.cube_api_key,
          errors: errors_on_object(project.project_setting)
        }
      end

      private

      def allowed?(project)
        return false unless project
        return false if project.personal?

        true
      end
    end
  end
end
