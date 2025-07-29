# frozen_string_literal: true

module Resolvers
  module SecretsManagement
    class ProjectSecretViewResolver < BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource
      include ResolvesProject

      type ::Types::SecretsManagement::ProjectSecretType, null: true

      argument :project_path, GraphQL::Types::ID,
        required: true,
        description: 'Project the secrets belong to.'

      argument :name, GraphQL::Types::String,
        required: true,
        description: 'Name of the project secret to view.'

      authorize :read_project_secrets

      def resolve(project_path:, name:)
        project = authorized_find!(project_path: project_path)

        result = ::SecretsManagement::ProjectSecrets::ReadService.new(project, current_user).execute(name)

        if result.success?
          result.payload[:project_secret]
        else
          raise_resource_not_available_error!(result.message)
        end
      end

      private

      def find_object(project_path:)
        resolve_project(full_path: project_path)
      end
    end
  end
end
