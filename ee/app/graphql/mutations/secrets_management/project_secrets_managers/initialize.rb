# frozen_string_literal: true

module Mutations
  module SecretsManagement
    module ProjectSecretsManagers
      class Initialize < BaseMutation
        graphql_name 'ProjectSecretsManagerInitialize'

        include ResolvesProject
        include Gitlab::InternalEventsTracking

        authorize :admin_project_secrets_manager

        argument :project_path, GraphQL::Types::ID,
          required: true,
          description: 'Project of the secrets manager.'

        field :project_secrets_manager,
          Types::SecretsManagement::ProjectSecretsManagerType,
          null: true,
          description: "Project secrets manager."

        def resolve(project_path:)
          project = authorized_find!(project_path: project_path)

          if Feature.disabled?(:secrets_manager, project)
            raise_resource_not_available_error!("`secrets_manager` feature flag is disabled.")
          end

          result = ::SecretsManagement::ProjectSecretsManagers::InitializeService
            .new(project, current_user)
            .execute

          if result.success?
            track_event(project)
            {
              project_secrets_manager: result.payload[:project_secrets_manager],
              errors: []
            }
          else
            {
              project_secrets_manager: nil,
              errors: [result.message]
            }
          end
        end

        private

        def track_event(project)
          track_internal_event(
            'enable_ci_secrets_manager_for_project',
            project: project,
            user: current_user,
            namespace: project.namespace,
            additional_properties: {
              label: 'graphql'
            }
          )
        end

        def find_object(project_path:)
          resolve_project(full_path: project_path)
        end
      end
    end
  end
end
