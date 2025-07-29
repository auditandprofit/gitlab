# frozen_string_literal: true

module Groups
  class DependenciesController < Groups::ApplicationController
    include GovernUsageGroupTracking
    include Gitlab::InternalEventsTracking

    before_action only: :index do
      push_frontend_feature_flag(:dependency_paths, group)
      push_frontend_feature_flag(:group_dependencies_graphql, group)
    end

    before_action :authorize_read_dependency_list!
    before_action :validate_project_ids_limit!, only: :index
    before_action :validate_component_versions!, only: :index

    feature_category :dependency_management
    urgency :low
    track_govern_activity 'dependencies', :index

    PROJECT_IDS_LIMIT = 10
    COMPONENT_NAMES_LIMIT_FOR_VERSION_FILTERING = 1

    def index
      respond_to do |format|
        format.html do
          track_internal_event(
            "visit_dependency_list",
            user: current_user,
            namespace: group
          )
          render status: :ok
        end
        format.json do
          track_internal_event(
            "called_dependency_api",
            user: current_user,
            namespace: group,
            additional_properties: {
              label: 'json'
            }
          )
          render json: dependencies_serializer.represent(dependencies)
        end
      end
    end

    def locations
      render json: ::Sbom::DependencyLocationListEntity.represent(
        Sbom::DependencyLocationsFinder.new(
          namespace: group,
          params: params.permit(:component_id, :search)
        ).execute
        .with_dependency_paths_existence
      )
    end

    def licenses
      catalogue = Gitlab::SPDX::Catalogue.latest

      licenses = catalogue
        .licenses
        .append(Gitlab::SPDX::License.unknown)
        .sort_by(&:name)

      render json: ::Sbom::DependencyLicenseListEntity.represent(licenses)
    end

    private

    def authorize_read_dependency_list!
      return if can?(current_user, :read_dependency, group)

      render_not_authorized
    end

    def validate_project_ids_limit!
      return unless params.fetch(:project_ids, []).size > PROJECT_IDS_LIMIT

      render_error(
        :unprocessable_entity,
        format(_('A maximum of %{limit} projects can be searched for at one time.'), limit: PROJECT_IDS_LIMIT)
      )
    end

    def validate_component_versions!
      return unless params[:component_versions] || (params[:not] && params[:not][:component_versions])

      if params.fetch(:component_names, []).size == COMPONENT_NAMES_LIMIT_FOR_VERSION_FILTERING
        track_internal_event(
          "filter_dependency_list_by_version",
          user: current_user,
          namespace: group
        )
      else
        render_error(
          :unprocessable_entity,
          format(_('Single component can be selected for component filter to be able to filter by version.'))
        )
      end
    end

    def dependencies
      if using_new_query?
        finder = ::Sbom::AggregationsFinder.new(group, params: dependencies_finder_params)
        relation = finder.execute
                         .with_component
                         .with_version

        paginator = Gitlab::Pagination::Keyset::Paginator.new(
          scope: relation.dup,
          cursor: params[:cursor],
          per_page: per_page
        )

        apply_pagination_headers!(paginator)

        relation
      else
        ::Sbom::DependenciesFinder.new(group, params: dependencies_finder_params).execute
          .with_component
          .with_version
          .with_source
          .with_project_route
      end
    end

    def dependencies_finder_params
      finder_params = params.permit(
        :cursor,
        :page,
        :per_page,
        :sort,
        :sort_by,
        licenses: [],
        package_managers: [],
        project_ids: [],
        component_ids: [],
        component_names: [],
        component_versions: [],
        not: { component_versions: [] }
      )

      finder_params[:sort_by] = map_sort_by(finder_params[:sort_by]) if using_new_query?

      finder_params
    end

    def dependencies_serializer
      serializer = DependencyListSerializer.new(project: nil, group: group, user: current_user)
      serializer = serializer.with_pagination(request, response) unless using_new_query?
      serializer
    end

    def render_not_authorized
      respond_to do |format|
        format.html do
          render_404
        end
        format.json do
          render_403
        end
      end
    end

    def render_error(status, message)
      respond_to do |format|
        format.json do
          render json: { message: message }, status: status
        end
      end
    end

    def apply_pagination_headers!(paginator)
      response.header['X-Next-Page'] = paginator.cursor_for_next_page
      response.header['X-Page'] = params[:cursor]
      response.header['X-Page-Type'] = 'cursor'
      response.header['X-Prev-Page'] = paginator.cursor_for_previous_page
      response.header['X-Per-Page'] = per_page
    end

    def map_sort_by(sort_by)
      case sort_by
      when 'name'
        :component_name
      when 'packager'
        :package_manager
      when 'license'
        :primary_license_spdx_identifier
      when 'severity'
        :highest_severity
      else
        sort_by&.to_sym
      end
    end

    def per_page
      params[:per_page]&.to_i || Sbom::AggregationsFinder::DEFAULT_PAGE_SIZE
    end

    def using_new_query?
      params[:project_ids].blank?
    end
  end
end
