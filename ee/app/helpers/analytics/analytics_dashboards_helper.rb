# frozen_string_literal: true

module Analytics
  module AnalyticsDashboardsHelper
    def analytics_dashboards_list_app_data(namespace)
      is_project = project?(namespace)
      is_group = group?(namespace)
      can_read_customizable_dashboards = can?(current_user, :read_customizable_dashboards, namespace)

      {
        namespace_id: namespace.id,
        is_project: is_project.to_s,
        is_group: is_group.to_s,
        dashboard_project: analytics_dashboard_pointer_project(namespace)&.to_json,
        can_configure_project_settings: can_configure_project_settings?(namespace).to_s,
        can_select_gitlab_managed_provider: can_select_gitlab_managed_provider?(namespace).to_s,
        managed_cluster_purchased: managed_cluster_purchased?(namespace).to_s,
        tracking_key: can_read_customizable_dashboards && is_project ? tracking_key(namespace) : nil,
        collector_host: can_read_customizable_dashboards ? collector_host(namespace) : nil,
        dashboard_empty_state_illustration_path: image_path('illustrations/empty-state/empty-dashboard-md.svg'),
        analytics_settings_path: analytics_settings_path(namespace),
        namespace_name: namespace.name,
        namespace_full_path: namespace.full_path,
        features: is_project ? enabled_analytics_features(namespace).to_json : [].to_json,
        router_base: router_base(namespace),
        root_namespace_name: namespace.root_ancestor.name,
        root_namespace_full_path: namespace.root_ancestor.full_path,
        is_instance_configured_with_self_managed_analytics_provider:
          instance_configured_with_self_managed_analytics_provider?(namespace).to_s,
        default_use_instance_configuration: default_use_instance_configuration?(namespace).to_s,
        overview_counts_aggregation_enabled: overview_counts_aggregation_enabled?(namespace).to_s,
        has_scoped_labels_feature: has_scoped_labels_feature?(namespace).to_s,
        data_source_clickhouse: ::Gitlab::ClickHouse.enabled_for_analytics?(namespace).to_s
      }
    end

    def analytics_project_settings_data(project)
      can_read_customizable_dashboards = can?(current_user, :read_customizable_dashboards, project)

      {
        tracking_key: can_read_customizable_dashboards ? tracking_key(project) : nil,
        collector_host: can_read_customizable_dashboards ? collector_host(project) : nil,
        dashboards_path: project_analytics_dashboards_path(project)
      }
    end

    private

    def project?(namespace)
      namespace.is_a?(Project)
    end

    def group?(namespace)
      namespace.is_a?(Group)
    end

    def collector_host(project)
      if project?(project)
        ::ProductAnalytics::Settings.for_project(project).product_analytics_data_collector_host
      else
        ::Gitlab::CurrentSettings.product_analytics_data_collector_host
      end
    end

    def tracking_key(project)
      project.project_setting.product_analytics_instrumentation_key
    end

    def enabled_analytics_features(project)
      [].tap do |features|
        features << :product_analytics if product_analytics_enabled?(project)
      end
    end

    def product_analytics_enabled?(project)
      ::ProductAnalytics::Settings.for_project(project).enabled? &&
        ::Feature.enabled?(:product_analytics_features, project) &&
        project.licensed_feature_available?(:product_analytics) &&
        can?(current_user, :read_customizable_dashboards, project)
    end

    def overview_counts_aggregation_enabled?(namespace)
      root_namespace = namespace.root_ancestor
      return true if root_namespace.value_stream_dashboard_aggregation&.enabled

      false
    end

    def can_configure_project_settings?(namespace)
      return false unless project?(namespace)

      can?(current_user, :admin_project, namespace)
    end

    def can_select_gitlab_managed_provider?(project)
      return false unless project?(project)
      return false unless ::Feature.enabled?(:product_analytics_billing, project.root_ancestor)

      # rubocop:disable Gitlab/AvoidGitlabInstanceChecks -- GitLab-managed provider is currently ONLY available on .com
      Gitlab::CurrentSettings.should_check_namespace_plan?
      # rubocop:enable Gitlab/AvoidGitlabInstanceChecks
    end

    def managed_cluster_purchased?(project)
      return false unless project?(project)

      ::Feature.enabled?(:product_analytics_billing_override, project.root_ancestor) ||
        ::GitlabSubscriptions::AddOnPurchase.active.for_product_analytics.by_namespace(project.root_ancestor).any?
    end

    def project_dashboard_pointer(project)
      if project.analytics_dashboards_pointer.present?
        project.analytics_dashboards_pointer.target_project
      else
        project
      end
    end

    def group_dashboard_pointer(group)
      return unless group.analytics_dashboards_pointer.present?

      group.all_projects.find_by_id(group.analytics_dashboards_pointer.target_project_id)
    end

    def analytics_dashboard_pointer_project(namespace)
      pointer_project = project?(namespace) ? project_dashboard_pointer(namespace) : group_dashboard_pointer(namespace)

      return unless pointer_project

      {
        id: pointer_project.id,
        full_path: pointer_project.full_path,
        name: pointer_project.name,
        default_branch: pointer_project.default_branch
      }
    end

    def router_base(namespace)
      return project_analytics_dashboards_path(namespace) if project?(namespace)

      group_analytics_dashboards_path(namespace)
    end

    def analytics_settings_path(namespace)
      settings_path =
        if project?(namespace)
          project_settings_analytics_path(namespace)
        else
          edit_group_path(namespace)
        end

      "#{settings_path}#js-analytics-dashboards-settings"
    end

    def instance_configured_with_self_managed_analytics_provider?(namespace)
      instance_collector_host = ::Gitlab::CurrentSettings.product_analytics_data_collector_host

      instance_collector_host.present? && namespace.has_self_managed_collector?(instance_collector_host)
    end

    def default_use_instance_configuration?(namespace)
      return true unless project?(namespace)

      empty_project_analytics_provider_settings?(namespace) &&
        instance_configured_with_self_managed_analytics_provider?(namespace)
    end

    def empty_project_analytics_provider_settings?(namespace)
      analytics_settings = namespace.project_setting.slice(
        :product_analytics_configurator_connection_string,
        :product_analytics_data_collector_host,
        :cube_api_base_url,
        :cube_api_key
      )

      analytics_settings.values.all?(&:blank?)
    end

    def has_scoped_labels_feature?(namespace)
      namespace.licensed_feature_available?(:scoped_labels)
    end
  end
end
