# frozen_string_literal: true

module Resolvers
  module SecretsManagement
    class ProjectSecretsManagerResolver < BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource
      include ResolvesProject

      type ::Types::SecretsManagement::ProjectSecretsManagerType, null: true

      argument :project_path, GraphQL::Types::ID,
        required: true,
        description: 'Project of the secrets manager.'

      authorize :read_project_secrets_manager_status

      def resolve(project_path:)
        project = authorized_find!(project_path: project_path)
        project.secrets_manager
      end

      private

      def find_object(project_path:)
        resolve_project(full_path: project_path)
      end
    end
  end
end
