# frozen_string_literal: true

module API
  class Dependencies < ::API::Base
    include PaginationParams

    feature_category :dependency_management
    urgency :low

    helpers do
      def dependencies_by(params)
        project = params[:project]
        params[:package_managers] = params.delete(:package_manager)
        dependencies = ::Sbom::DependenciesFinder.new(project, params: params).execute.with_component.with_version
        dependencies = dependencies.with_vulnerabilities if params[:preload_vulnerabilities]
        dependencies
      end
    end

    before { authenticate! }

    params do
      requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the project'
    end

    resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      desc 'Get a list of project dependencies' do
        success code: 200, model: ::EE::API::Entities::Dependency
        failure [{ code: 401, message: 'Unauthorized' }, { code: 404, message: 'Not found' }]
      end

      params do
        optional :package_manager,
          type: Array[String],
          coerce_with: Validations::Types::CommaSeparatedToArray.coerce,
          desc: "Returns dependencies belonging to specified package managers: #{::Sbom::DependenciesFinder::FILTER_PACKAGE_MANAGERS_VALUES.join(', ')}.",
          values: ::Sbom::DependenciesFinder::FILTER_PACKAGE_MANAGERS_VALUES,
          documentation: { example: 'maven,yarn' }
        use :pagination
      end

      get ':id/dependencies' do
        authorize! :read_dependency, user_project

        ::Gitlab::Tracking.event(self.options[:for].name, 'view_dependencies', project: user_project, user: current_user, namespace: user_project.namespace)

        dependency_params = declared_params(include_missing: false)
          .merge(
            project: user_project,
            preload_vulnerabilities: Ability.allowed?(current_user, :read_vulnerability, user_project)
          )
        dependencies = paginate(dependencies_by(dependency_params))

        present dependencies, with: ::EE::API::Entities::Dependency, user: current_user, project: user_project
      end
    end
  end
end
