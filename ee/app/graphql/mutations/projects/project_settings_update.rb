# frozen_string_literal: true

module Mutations
  module Projects
    class ProjectSettingsUpdate < BaseMutation
      graphql_name 'ProjectSettingsUpdate'

      include FindsProject
      include Gitlab::Utils::StrongMemoize

      authorize :admin_project

      argument :full_path,
        GraphQL::Types::ID,
        required: true,
        description: 'Full Path of the project the settings belong to.'

      argument :duo_features_enabled,
        GraphQL::Types::Boolean,
        required: false,
        description: 'Indicates whether GitLab Duo features are enabled for the project.'

      argument :duo_context_exclusion_settings,
        Types::Projects::Input::DuoContextExclusionSettingsInputType,
        required: false,
        description: 'Settings for excluding files from Duo context.'

      argument :web_based_commit_signing_enabled,
        GraphQL::Types::Boolean,
        required: false,
        description: 'Indicates whether web-based commit signing is enabled for the project.',
        experiment: { milestone: '18.2' }

      field :project_settings,
        Types::Projects::SettingType,
        null: false,
        description: 'Project settings after mutation.'

      def resolve(full_path:, **args)
        raise raise_resource_not_available_error! unless allowed?

        project = authorized_find!(full_path)

        # Process duo_context_exclusion_settings to convert it to a hash if present
        if args[:duo_context_exclusion_settings].present?
          args[:duo_context_exclusion_settings] = args[:duo_context_exclusion_settings].to_h
        end

        args.compact!

        raise Gitlab::Graphql::Errors::ArgumentError, 'Must provide at least one argument' if args.empty?

        ::Projects::UpdateService.new(project, current_user, { project_setting_attributes: args }).execute

        {
          project_settings: project.project_setting,
          errors: errors_on_object(project.project_setting)
        }
      end

      private

      def allowed?
        return true if ::Gitlab::Saas.feature_available?(:duo_chat_on_saas)
        return false unless ::License.feature_available?(:code_suggestions)

        ::GitlabSubscriptions::AddOnPurchase.active_duo_add_ons_exist?(:instance)
      end
    end
  end
end
