# frozen_string_literal: true

module EE
  module SearchController
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    class_methods do
      extend ::Gitlab::Utils::Override

      override :search_rate_limited_endpoints
      def search_rate_limited_endpoints
        super.push(:aggregations)
      end
    end

    prepended do
      # track unique users of advanced global search
      track_event :show,
        name: 'i_search_advanced',
        conditions: -> { track_search_advanced? },
        label: 'redis_hll_counters.search.search_total_unique_counts_monthly',
        action: 'executed',
        destinations: [:redis_hll, :snowplow]

      track_event :autocomplete,
        name: 'i_search_advanced',
        conditions: -> { track_search_advanced? },
        label: 'redis_hll_counters.search.search_total_unique_counts_monthly',
        action: 'autocomplete',
        destinations: [:redis_hll, :snowplow]

      # track unique paid users (users who already use elasticsearch and users who could use it if they enable
      # elasticsearch integration)
      # for gitlab.com we check if the search uses elasticsearch
      # for self-managed we check if the licensed feature available
      track_event :show,
        name: 'i_search_paid',
        conditions: -> { track_search_paid? },
        label: 'redis_hll_counters.search.i_search_paid_monthly',
        action: 'executed',
        destinations: [:redis_hll, :snowplow]

      track_event :autocomplete,
        name: 'i_search_paid',
        conditions: -> { track_search_paid? },
        label: 'redis_hll_counters.search.i_search_paid_monthly',
        action: 'autocomplete',
        destinations: [:redis_hll, :snowplow]

      rescue_from Elastic::TimeoutError, with: :render_timeout

      before_action :check_search_rate_limit!, only: search_rate_limited_endpoints

      before_action only: :show do
        push_frontend_feature_flag(:zoekt_cross_namespace_search, current_user)
      end

      before_action :sso_enforcement_redirect, only: [:show]

      after_action :run_index_integrity_worker, only: :show, if: :no_results_for_group_or_project_blobs_advanced_search?
    end

    def aggregations
      params.require(:search)

      # Cache the response on the frontend
      cache_for = ::Gitlab::Saas.feature_available?(:advanced_search) ? 5.minutes : 1.minute
      expires_in cache_for

      if search_term_valid?
        render json: search_service.search_aggregations.to_json
      else
        render json: { error: flash[:alert] }, status: :bad_request
      end
    end

    private

    override :multi_match?
    def multi_match?(search_type:, scope:)
      scope == 'blobs' && search_type == 'zoekt'
    end

    override :default_sort
    def default_sort
      if search_service.use_elasticsearch?
        'relevant'
      else
        super
      end
    end

    def track_search_advanced?
      search_service.use_elasticsearch?
    end

    def track_search_paid?
      if ::Gitlab::Saas.feature_available?(:advanced_search)
        search_service.use_elasticsearch?
      else
        License.feature_available?(:elastic_search)
      end
    end

    override :payload_metadata
    def payload_metadata
      super.merge(
        'meta.search.filters.source_branch' => filter_params[:source_branch],
        'meta.search.filters.not_source_branch' => filter_params.dig(:not, :source_branch),
        'meta.search.filters.target_branch' => filter_params[:target_branch],
        'meta.search.filters.not_target_branch' => filter_params.dig(:not, :target_branch),
        'meta.search.filters.author_username' => filter_params[:author_username],
        'meta.search.filters.not_author_username' => filter_params.dig(:not, :author_username))
    end

    def no_results_for_group_or_project_blobs_advanced_search?
      return false unless search_service.scope == 'blobs'
      return false unless search_service.project || search_service.group
      return false unless search_type == 'advanced'

      search_service.search_objects.blank?
    end

    def run_index_integrity_worker
      if search_service.project.present?
        ::Search::ProjectIndexIntegrityWorker.perform_async(search_service.project.id)
      else
        ::Search::NamespaceIndexIntegrityWorker.perform_async(search_service.group.id)
      end
    end

    override :filter_params
    def filter_params
      permitted_filter_params = [:source_branch, :target_branch, :author_username]
      super.merge(params.permit(
        *permitted_filter_params,
        not: permitted_filter_params
      ))
    end

    def sso_enforcement_redirect
      # redirection should occur for group searches only
      return unless search_service.level.to_sym == :group

      search_group = search_service.group
      return unless search_group

      params = { user: current_user, resource: search_group, skip_owner_check: true }
      redirect = ::Gitlab::Auth::GroupSaml::SsoEnforcer.access_restricted?(**params)
      return unless redirect

      redirect_to sso_group_saml_providers_url(search_group.root_ancestor, { redirect: request.fullpath })
    end
  end
end
