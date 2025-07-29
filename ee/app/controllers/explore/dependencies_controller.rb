# frozen_string_literal: true

# Warning: The group level Dependency list has experienced quite a few
# performance problems when adding features like filtering,
# grouping, sorting, and advanced pagination. Because of this
# the group level Dependency list is limited to groups that are
# below a specific threshold. Those same limits have not been
# considered or added here yet.
#
# See https://gitlab.com/gitlab-org/gitlab/-/blob/b3d0d3b3633e04cabe5de1359fa1d93ba824d142/ee/app/controllers/groups/dependencies_controller.rb#L18-19
# for additional context.

module Explore
  class DependenciesController < ::Explore::ApplicationController
    include GovernUsageTracking

    track_govern_activity 'dependencies', :index
    feature_category :dependency_management
    urgency :low

    before_action :authorize_explore_dependencies!

    before_action do
      push_frontend_feature_flag(:explore_dependencies, current_user)
    end

    def index
      paginator = dependencies.keyset_paginate(
        cursor: finder_params[:cursor],
        per_page: per_page
      )
      respond_to do |format|
        format.html do
          @page_info = formatted_page_info(paginator)
          render status: :ok
        end
        format.json do
          render json: serializer.represent(paginator)
        end
      end
    end

    private

    def finder
      ::Sbom::DependenciesFinder.new(
        organization,
        current_user: current_user,
        params: finder_params
      )
    end

    def finder_params
      params.permit(:cursor)
    end

    def serializer
      DependencyListSerializer
        .new(organization: organization, user: current_user)
        .with_pagination(request, response)
    end

    def organization
      @organization ||= Current.organization
    end

    def dependencies
      finder
        .execute
        .with_component
        .with_project_namespace
        .with_project_route
        .with_source
        .with_version
        .with_dependency_paths_existence
    end

    def per_page
      Gitlab::Pagination::Keyset::Page
        .new(per_page: pagination_params[:per_page].to_i)
        .per_page
    end

    def authorize_explore_dependencies!
      return render_404 unless current_user.present?
      return render_404 unless Feature.enabled?(:explore_dependencies, current_user)

      render_403 unless can?(current_user, :read_dependency, organization)
    end

    def page_info(paginator)
      {
        type: "cursor",
        has_next_page: paginator.has_next_page?,
        has_previous_page: paginator.has_previous_page?,
        start_cursor: paginator.cursor_for_previous_page,
        current_cursor: finder_params[:cursor],
        end_cursor: paginator.cursor_for_next_page
      }
    end

    def formatted_page_info(paginator)
      Gitlab::Json.generate(page_info(paginator))
    end

    def tracking_namespace_source
      current_user.namespace
    end

    def tracking_project_source
      nil
    end
  end
end
