# frozen_string_literal: true

module Analytics
  class Visualization
    include SchemaValidator

    attr_reader :type, :container, :data, :options, :config, :slug, :errors

    VISUALIZATIONS_ROOT_LOCATION = '.gitlab/analytics/dashboards/visualizations'
    SCHEMA_PATH = 'ee/app/validators/json_schemas/analytics_visualization.json'

    PRODUCT_ANALYTICS_PATH = 'ee/lib/gitlab/analytics/product_analytics/visualizations'
    PRODUCT_ANALYTICS_VISUALIZATIONS = %w[
      average_session_duration
      average_sessions_per_user
      browsers_per_users
      daily_active_users
      events_over_time
      page_views_over_time
      returning_users_percentage
      sessions_over_time
      sessions_per_browser
      top_pages
      total_events
      total_pageviews
      total_sessions
      total_unique_users
    ].freeze

    DORA_METRICS_VISUALIZATIONS_PATH = 'ee/lib/gitlab/analytics/dora_metrics/visualizations'
    DORA_METRICS_VISUALIZATIONS = %w[
      deployment_frequency_average
      time_to_restore_service_median
      lead_time_for_changes_median
      change_failure_rate
      deployment_frequency_over_time
      change_failure_rate_over_time
      time_to_restore_service_over_time
      lead_time_for_changes_over_time
    ].freeze

    VALUE_STREAM_DASHBOARD_PATH = 'ee/lib/gitlab/analytics/value_stream_dashboard/visualizations'
    VALUE_STREAM_DASHBOARD_VISUALIZATIONS = %w[
      dora_chart
      vsd_lifecycle_metrics_table
      vsd_dora_metrics_table
      vsd_security_metrics_table
      usage_overview
      dora_performers_score
      dora_projects_comparison
      namespace_metadata
      groups_count
      users_count
      projects_count
      issues_count
      merge_requests_count
      pipelines_count
    ].freeze

    AI_IMPACT_DASHBOARD_PATH = 'ee/lib/gitlab/analytics/ai_impact_dashboard/visualizations'
    AI_IMPACT_DASHBOARD_VISUALIZATIONS = %w[
      ai_impact_table
      ai_impact_lifecycle_metrics_table
      ai_impact_ai_metrics_table
      code_suggestions_usage_rate_over_time
      code_suggestions_acceptance_rate_over_time
      duo_chat_usage_rate_over_time
      duo_usage_rate_over_time
    ].freeze

    CONTRIBUTIONS_DASHBOARD_PATH = 'ee/lib/gitlab/analytics/contributions_dashboard/visualizations'
    CONTRIBUTIONS_DASHBOARD_VISUALIZATIONS = %w[
      pushes
      merge_requests
      issues
      contributions_by_user
    ].freeze

    VISUALIZATIONS_FOR_GROUP_ONLY = %w[
      dora_performers_score
      dora_projects_comparison
      groups_count
      users_count
      projects_count
    ].freeze

    MERGE_REQUESTS_VISUALIZATIONS_PATH = 'ee/lib/gitlab/analytics/merge_requests/visualizations'
    MERGE_REQUESTS_VISUALIZATIONS = %w[
      mean_time_to_merge
      merge_requests_over_time
      merge_requests_throughput_table
    ].freeze

    DUO_USAGE_VISUALIZATIONS_PATH = 'ee/lib/gitlab/analytics/duo_usage_analytics/visualizations'
    DUO_USAGE_VISUALIZATIONS = %w[duo_seat_engagement_rate_over_time].freeze

    def self.for(container:, user:)
      config_project =
        container.analytics_dashboards_configuration_project ||
        container.default_dashboards_configuration_source

      visualizations = []
      visualizations << custom_visualizations(container, config_project)
      visualizations << builtin_visualizations(container, user)

      visualizations.flatten
    end

    def self.custom_visualizations(container, config_project)
      trees = config_project&.repository&.tree(:head, VISUALIZATIONS_ROOT_LOCATION)

      return [] unless trees.present?

      trees.entries.map do |entry|
        config = config_project.repository.blob_data_at(config_project.repository.root_ref_sha, entry.path)

        new(container: container, config: config, slug: File.basename(entry.name, File.extname(entry.name)))
      end
    end

    def self.from_file(filename:, config_project:, container:)
      return unless filename

      content = load_project_visualization_data(filename: filename, project: config_project)
      content ||= load_builtin_visualization_data(filename: filename)

      if content
        new(container: container, config: content, slug: filename)
      else
        new(container: container, config: nil, slug: filename,
          init_error: "Visualization file #{filename}.yaml not found")
      end
    end

    def self.from_data(data:, container:)
      return unless data

      slug = if data.key?('slug')
               data['slug']
             else
               SecureRandom.alphanumeric(10)
             end

      new(container: container, config: YAML.safe_dump(data), slug: slug)
    end

    def self.skip_for_project_namespace?(name)
      VISUALIZATIONS_FOR_GROUP_ONLY.include?(name)
    end

    def self.product_analytics_visualizations(container, is_project = false)
      unsafe_load_builtin_visualizations(PRODUCT_ANALYTICS_VISUALIZATIONS, PRODUCT_ANALYTICS_PATH, container,
        is_project)
    end

    def self.value_stream_dashboard_visualizations(container, is_project = false)
      unsafe_load_builtin_visualizations(VALUE_STREAM_DASHBOARD_VISUALIZATIONS, VALUE_STREAM_DASHBOARD_PATH, container,
        is_project)
    end

    def self.ai_impact_dashboard_visualizations(container, is_project = false)
      unsafe_load_builtin_visualizations(AI_IMPACT_DASHBOARD_VISUALIZATIONS, AI_IMPACT_DASHBOARD_PATH, container,
        is_project)
    end

    def self.dora_metrics_visualizations(container, is_project = false)
      unsafe_load_builtin_visualizations(DORA_METRICS_VISUALIZATIONS, DORA_METRICS_VISUALIZATIONS_PATH, container,
        is_project)
    end

    def self.merge_requests_visualizations(container)
      unsafe_load_builtin_visualizations(MERGE_REQUESTS_VISUALIZATIONS, MERGE_REQUESTS_VISUALIZATIONS_PATH, container,
        true)
    end

    def self.duo_usage_visualizations(container, is_project = false)
      unsafe_load_builtin_visualizations(DUO_USAGE_VISUALIZATIONS, DUO_USAGE_VISUALIZATIONS_PATH, container, is_project)
    end

    def self.builtin_visualizations(container, user)
      is_project = container.is_a?(Project)

      visualizations = []

      if container.product_analytics_enabled? && container.product_analytics_onboarded?(user)
        visualizations << product_analytics_visualizations(container, is_project)
      end

      if container.value_streams_dashboard_available?
        visualizations << value_stream_dashboard_visualizations(container, is_project)
      end

      if container.value_streams_dashboard_available? && container.dora_metrics_dashboard_enabled?(user)
        visualizations << dora_metrics_visualizations(container, is_project)
      end

      if container.ai_impact_dashboard_available_for?(user)
        visualizations << ai_impact_dashboard_visualizations(container, is_project)
      end

      visualizations << duo_usage_visualizations(container, is_project) if container.duo_usage_dashboard_enabled?(user)

      visualizations << merge_requests_visualizations(container) if container.merge_request_analytics_enabled?(user)

      visualizations.flatten
    end

    def initialize(container:, config:, slug:, init_error: nil)
      raise ArgumentError, 'container cannot be nil' if container.nil?

      if init_error
        initialize_with_error(container, init_error, slug)
        return
      end

      begin
        @config = YAML.safe_load(config)
        @type = @config['type']
        @options = @config['options']
        @data = @config['data']
      rescue Psych::Exception => e
        @errors = [e.message]
      end
      @container = container
      @slug = slug&.parameterize
      @errors = schema_errors_for(@config)
    end

    def initialize_with_error(container, init_error, slug)
      raise ArgumentError, 'container cannot be nil' if container.nil?

      @container = container
      @options = {}
      @type = 'unknown'
      @data = {}
      @errors = [init_error]
      @slug = slug&.parameterize
    end

    class << self
      private

      def get_path_for_visualization(data)
        if VALUE_STREAM_DASHBOARD_VISUALIZATIONS.include?(data)
          VALUE_STREAM_DASHBOARD_PATH
        elsif AI_IMPACT_DASHBOARD_VISUALIZATIONS.include?(data)
          AI_IMPACT_DASHBOARD_PATH
        elsif CONTRIBUTIONS_DASHBOARD_VISUALIZATIONS.include?(data)
          CONTRIBUTIONS_DASHBOARD_PATH
        elsif DORA_METRICS_VISUALIZATIONS.include?(data)
          DORA_METRICS_VISUALIZATIONS_PATH
        elsif MERGE_REQUESTS_VISUALIZATIONS.include?(data)
          MERGE_REQUESTS_VISUALIZATIONS_PATH
        elsif DUO_USAGE_VISUALIZATIONS.include?(data)
          DUO_USAGE_VISUALIZATIONS_PATH
        else
          PRODUCT_ANALYTICS_PATH
        end
      end

      def visualization_config_path(data)
        "#{Analytics::Dashboard::DASHBOARD_ROOT_LOCATION}/visualizations/#{data}.yaml"
      end

      def load_project_visualization_data(filename:, project:)
        return unless project && !project.empty_repo?

        project.repository.blob_data_at(
          project.repository.root_ref_sha,
          visualization_config_path(filename)
        )
      end

      def load_builtin_visualization_data(filename:)
        path = get_path_for_visualization(filename)
        file = Rails.root.join(path, "#{filename}.yaml")

        Gitlab::PathTraversal.check_path_traversal!(filename)
        Gitlab::PathTraversal.check_allowed_absolute_path!(
          file.to_s, [Rails.root.join(path).to_s]
        )

        File.read(file)
      rescue Errno::ENOENT
        nil
      end

      def unsafe_load_builtin_visualizations(visualization_names, directory, container, is_project)
        visualization_names.filter_map do |name|
          next if is_project && skip_for_project_namespace?(name)

          config = File.read(Rails.root.join(directory, "#{name}.yaml"))

          new(container: container, config: config, slug: name)
        end
      end
    end
  end
end
