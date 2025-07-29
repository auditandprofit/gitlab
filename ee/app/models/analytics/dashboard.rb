# frozen_string_literal: true

module Analytics
  class Dashboard
    include SchemaValidator

    attr_reader :title, :description, :schema_version, :status, :panels, :container,
      :config_project, :slug, :path, :user_defined, :category, :errors, :filters

    DASHBOARD_ROOT_LOCATION = '.gitlab/analytics/dashboards'

    PRODUCT_ANALYTICS_DASHBOARDS_LIST = %w[audience behavior].freeze
    VALUE_STREAMS_DASHBOARD_NAME = 'value_streams_dashboard'
    AI_IMPACT_DASHBOARD_NAME = 'ai_impact'
    CONTRIBUTION_DASHBOARD_NAME = 'contributions_dashboard'
    PROJECT_VALUE_STREAMS_DASHBOARD_NAME = 'project_value_streams_dashboard'
    SCHEMA_PATH = 'ee/app/validators/json_schemas/analytics_dashboard.json'

    def self.for(container:, user:)
      unless container.is_a?(Group) || container.is_a?(Project)
        raise ArgumentError,
          "A group or project must be provided. Given object is #{container.class.name} type"
      end

      config_project =
        container.analytics_dashboards_configuration_project ||
        container.default_dashboards_configuration_source

      dashboards = []

      root_trees = config_project&.repository&.tree(:head, DASHBOARD_ROOT_LOCATION)

      dashboards << builtin_dashboards(container, config_project, user)
      dashboards << customized_dashboards(container, config_project, root_trees.trees) if root_trees&.trees

      dashboards.flatten.compact
    end

    def self.customized_dashboards(container, config_project, trees)
      trees.delete_if { |tree| tree.name == 'visualizations' }.map do |tree|
        config_data =
          config_project.repository.blob_data_at(config_project.repository.root_ref_sha,
            "#{tree.path}/#{tree.name}.yaml")

        next unless config_data

        config = YAML.safe_load(config_data)

        new(
          slug: tree.name,
          container: container,
          config: config,
          config_project: config_project,
          user_defined: true
        )
      end
    end

    def self.load_yaml_dashboard_config(name, file_path)
      Gitlab::PathTraversal.check_allowed_absolute_path_and_path_traversal!(name, [])

      YAML.safe_load(
        File.read(Rails.root.join(file_path, "#{name}.yaml"))
      )
    end

    def self.product_analytics_dashboards(container, config_project, user)
      return [] unless container.product_analytics_enabled?
      return [] unless container.product_analytics_onboarded?(user)

      PRODUCT_ANALYTICS_DASHBOARDS_LIST.map do |name|
        config = load_yaml_dashboard_config(name, 'ee/lib/gitlab/analytics/product_analytics/dashboards')

        new(
          slug: name,
          container: container,
          config: config,
          config_project: config_project,
          user_defined: false
        )
      end
    end

    def self.value_stream_dashboard(container, config_project)
      return unless container.value_streams_dashboard_available?

      config_file_name = container.is_a?(Group) ? VALUE_STREAMS_DASHBOARD_NAME : PROJECT_VALUE_STREAMS_DASHBOARD_NAME

      config =
        load_yaml_dashboard_config(
          config_file_name,
          'ee/lib/gitlab/analytics/value_stream_dashboard/dashboards'
        )

      new(
        slug: VALUE_STREAMS_DASHBOARD_NAME,
        container: container,
        config: config,
        config_project: config_project,
        user_defined: false
      )
    end

    def self.ai_impact_dashboard(container, config_project, user)
      return unless container.ai_impact_dashboard_available_for?(user)

      config = load_yaml_dashboard_config('dashboard', 'ee/lib/gitlab/analytics/ai_impact_dashboard')

      new(
        slug: AI_IMPACT_DASHBOARD_NAME,
        container: container,
        config: config,
        config_project: config_project,
        user_defined: false
      )
    end

    def self.duo_usage_dashboard(container, config_project, user)
      return unless container.duo_usage_dashboard_enabled?(user)

      config_file_name = container.is_a?(Group) ? 'duo_usage_dashboard' : 'project_duo_usage_dashboard'

      config =
        load_yaml_dashboard_config(
          config_file_name,
          'ee/lib/gitlab/analytics/duo_usage_analytics/dashboards'
        )

      new(
        slug: 'duo_usage',
        container: container,
        config: config,
        config_project: config_project,
        user_defined: false
      )
    end

    def self.contributions_dashboard(container, config_project)
      return unless container.contributions_dashboard_available?

      config = load_yaml_dashboard_config('dashboard', 'ee/lib/gitlab/analytics/contributions_dashboard')

      new(
        slug: CONTRIBUTION_DASHBOARD_NAME,
        container: container,
        config: config,
        config_project: config_project,
        user_defined: false
      )
    end

    def self.dora_metrics_dashboard(container, config_project)
      config = load_yaml_dashboard_config('dashboard', 'ee/lib/gitlab/analytics/dora_metrics')

      new(
        slug: 'dora_metrics',
        container: container,
        config: config,
        config_project: config_project,
        user_defined: false
      )
    end

    def self.merge_request_analytics_dashboard(container, config_project, user)
      return unless container.merge_request_analytics_enabled?(user)

      config = load_yaml_dashboard_config('dashboard', 'ee/lib/gitlab/analytics/merge_requests/dashboards')

      new(
        slug: 'merge_request_analytics',
        container: container,
        config: config,
        config_project: config_project,
        user_defined: false
      )
    end

    def self.builtin_dashboards(container, config_project, user)
      builtin = []

      builtin << product_analytics_dashboards(container, config_project, user)
      builtin << value_stream_dashboard(container, config_project)
      builtin << ai_impact_dashboard(container, config_project, user)
      builtin << contributions_dashboard(container, config_project)
      builtin << dora_metrics_dashboard(container, config_project) if container.dora_metrics_dashboard_enabled?(user)
      builtin << merge_request_analytics_dashboard(container, config_project, user)
      builtin << duo_usage_dashboard(container, config_project, user)

      builtin.flatten
    end

    def initialize(**args)
      @container = args[:container]
      @config_project = args[:config_project]
      @slug = args[:slug]
      @user_defined = args[:user_defined]

      @yaml_definition = args[:config]
      @title = @yaml_definition['title']
      @description = @yaml_definition['description']
      @schema_version = @yaml_definition['version']
      @status = @yaml_definition['status']
      @panels = Analytics::Panel.from_data(@yaml_definition['panels'], config_project, container)
      @category = 'analytics'

      @errors = schema_errors_for(@yaml_definition)
      @filters = @yaml_definition['filters']
    end

    def ==(other)
      slug == other.slug
    end

    private

    attr_reader :yaml_definition
  end
end
