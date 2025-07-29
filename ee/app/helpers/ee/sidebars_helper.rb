# frozen_string_literal: true

module EE
  module SidebarsHelper
    extend ::Gitlab::Utils::Override
    include ::Gitlab::Utils::StrongMemoize

    override :project_sidebar_context_data
    def project_sidebar_context_data(project, user, current_ref, **args)
      super.merge({
        show_promotions: show_promotions?(user),
        show_discover_project_security: show_discover_project_security?(project),
        learn_gitlab_enabled: ::Onboarding::LearnGitlab.available?(project.namespace, user),
        # Used to see if we're on get_started path for redesign rollout on learn_gitlab_redesign
        show_get_started_menu: current_path?('projects/get_started#show')
      })
    end

    override :group_sidebar_context_data
    def group_sidebar_context_data(group, user)
      super.merge(
        show_promotions: show_promotions?(user),
        show_discover_group_security: show_discover_group_security?(group)
      )
    end

    override :your_work_context_data
    def your_work_context_data(user)
      super.merge({
        show_security_dashboard: security_dashboard_available?
      })
    end

    override :super_sidebar_context
    def super_sidebar_context(user, group:, project:, panel:, panel_type:)
      return super unless user

      context = super
      root_namespace = (project || group)&.root_ancestor

      context.merge!(
        GitlabSubscriptions::Trials::WidgetPresenter.new(root_namespace, user: current_user).attributes
      )

      context[:trial] = {
        has_start_trial: trials_allowed?(user),
        url: new_trial_path(glm_source: 'gitlab.com', glm_content: 'top-right-dropdown')
      }

      show_buy_pipeline_minutes = show_buy_pipeline_minutes?(project, group)

      return context unless show_buy_pipeline_minutes && root_namespace.present?

      context.merge({
        pipeline_minutes: {
          show_buy_pipeline_minutes: show_buy_pipeline_minutes,
          show_notification_dot: show_pipeline_minutes_notification_dot?(project, group),
          show_with_subtext: show_buy_pipeline_with_subtext?(project, group),
          buy_pipeline_minutes_path: usage_quotas_path(root_namespace),
          tracking_attrs: {
            'track-action': 'click_buy_ci_minutes',
            'track-label': root_namespace.actual_plan_name,
            'track-property': 'user_dropdown'
          },
          notification_dot_attrs: {
            'data-track-action': 'render',
            'data-track-label': 'show_buy_ci_minutes_notification',
            'data-track-property': current_user.namespace.actual_plan_name
          },
          callout_attrs: {
            feature_id: ::Ci::RunnersHelper::BUY_PIPELINE_MINUTES_NOTIFICATION_DOT,
            dismiss_endpoint: callouts_path
          }
        }
      })
    end

    override :compare_plans_url
    def compare_plans_url(user: nil, project: nil, group: nil)
      return super unless user

      target_group = group if group&.persisted?
      target_group ||= project.namespace if project&.persisted? && project.namespace.is_a?(Group)

      if target_group && can?(user, :read_billing, target_group)
        group_billings_path(target_group)
      else
        promo_pricing_url
      end
    end

    private

    def super_sidebar_default_pins(panel_type)
      case panel_type
      when 'group'
        super << :group_epic_list
      else
        super
      end
    end
  end
end
