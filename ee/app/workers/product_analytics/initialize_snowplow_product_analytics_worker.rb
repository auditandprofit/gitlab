# frozen_string_literal: true

module ProductAnalytics
  class InitializeSnowplowProductAnalyticsWorker
    include ApplicationWorker
    include Analytics::ProductAnalytics::ConfiguratorUrlValidation

    data_consistency :sticky
    feature_category :product_analytics
    idempotent!
    worker_has_external_dependencies!

    PROJECT_PRODUCT_ANALYTICS_KEY = "project:%{project_id}:product_analytics_initializing"

    sidekiq_options retry: 1
    sidekiq_retries_exhausted do |msg|
      project_id = msg.dig('args', 0)
      Gitlab::Redis::SharedState.with { |r| r.del(format(PROJECT_PRODUCT_ANALYTICS_KEY, project_id: project_id)) }
    end

    def perform(project_id)
      @project = Project.find_by_id(project_id)

      return unless @project&.product_analytics_enabled?

      validate_url!(project_setup_url)

      response = Gitlab::HTTP.post(
        project_setup_url,
        allow_local_requests: allow_local_requests?,
        timeout: 10
      )

      ::ProductAnalytics::InitializeStackService.new(container: @project).unlock!

      if response.success?
        update_instrumentation_key(Gitlab::Json.parse(response.body)['app_id'])
        track_success
      else
        Gitlab::ErrorTracking.track_and_raise_exception(
          RuntimeError.new(response.body),
          project_id: @project.id
        )
      end
    rescue => e # rubocop:disable Style/RescueStandardError
      Gitlab::ErrorTracking.track_and_raise_exception(e, project_id: @project.id)
    end

    private

    def update_instrumentation_key(key)
      @project.project_setting.update!(product_analytics_instrumentation_key: key)
    end

    def project_setup_url
      URI.join(
        configurator_url(@project),
        '/setup-project/',
        "gitlab_project_#{@project.id}"
      )
    end

    def track_success
      Gitlab::UsageDataCounters::HLLRedisCounter.track_usage_event(
        'project_initialized_product_analytics',
        @project.id
      )
    end
  end
end
