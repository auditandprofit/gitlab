# frozen_string_literal: true

module Resolvers
  module Ai
    module DuoWorkflows
      class WorkflowsResolver < BaseResolver
        include Gitlab::Graphql::Authorize::AuthorizeResource

        type Types::Ai::DuoWorkflows::WorkflowType, null: false

        argument :project_path, GraphQL::Types::ID,
          required: false,
          description: 'Full path of the project that contains the flows.'

        argument :type, GraphQL::Types::String,
          required: false,
          description: 'Type of flow to filter by (for example, software_development).'

        argument :sort, Types::SortEnum,
          description: 'Sort flows by the criteria.',
          required: false,
          default_value: :created_desc

        argument :environment, Types::Ai::DuoWorkflows::WorkflowEnvironmentEnum,
          description: 'Environment, for example, IDE or web.',
          required: false

        argument :workflow_id, Types::GlobalIDType[::Ai::DuoWorkflows::Workflow],
          required: false,
          description: 'Flow ID to filter by.'

        def resolve(**args)
          return [] unless current_user

          if args[:workflow_id].present?
            return Gitlab::Graphql::Lazy.with_value(find_object(id: args[:workflow_id])) do |workflow|
              if workflow.nil?
                raise_resource_not_available_error! "Workflow not found"
              elsif !Ability.allowed?(current_user, :read_duo_workflow, workflow)
                raise_resource_not_available_error! "You don't have permission to access this workflow"
              else
                ::Ai::DuoWorkflows::Workflow.id_in([workflow.id])
              end
            end
          end

          workflows = ::Ai::DuoWorkflows::Workflow

          if object.is_a?(::Project)
            return [] unless current_user.can?(:duo_workflow, object)

            workflows = workflows.for_project(object).from_pipeline
          else
            workflows = workflows.for_user(current_user.id)
            if args[:project_path].present?
              project = Project.find_by_full_path(args[:project_path])

              return [] unless current_user.can?(:duo_workflow, project)

              workflows = workflows.for_project(project)
            end
          end

          workflows = workflows.with_workflow_definition(args[:type]) if args[:type].present?
          workflows = workflows.with_environment(args[:environment]) if args[:environment].present?

          workflows.order_by(args[:sort])
        end

        private

        def find_object(id:)
          GitlabSchema.find_by_gid(id)
        end
      end
    end
  end
end
