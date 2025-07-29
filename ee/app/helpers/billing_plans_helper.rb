# frozen_string_literal: true

module BillingPlansHelper
  include Gitlab::Utils::StrongMemoize
  include Gitlab::Allowable

  def subscription_plan_info(plans_data, current_plan_code)
    current_plan = plans_data.find { |plan| plan.code == current_plan_code && plan.current_subscription_plan? }
    current_plan || plans_data.find { |plan| plan.code == current_plan_code }
  end

  def number_to_plan_currency(value)
    number_to_currency(value, unit: '$', strip_insignificant_zeros: true, format: "%u%n")
  end

  def show_contact_sales_button?(purchase_link_action)
    purchase_link_action == 'upgrade'
  end

  def show_upgrade_button?(purchase_link_action, allow_upgrade)
    return false if allow_upgrade == false

    purchase_link_action == 'upgrade'
  end

  # [namespace] can be either a namespace or a group
  def can_edit_billing?(namespace)
    can?(current_user, :edit_billing, namespace)
  end

  # [namespace] can be either a namespace or a group
  def subscription_plan_data_attributes(namespace, plan, read_only: false)
    return {} unless namespace

    {
      namespace_id: namespace.id,
      namespace_name: namespace.name,
      add_seats_href: add_seats_url(namespace),
      plan_renew_href: plan_renew_url(namespace),
      customer_portal_url: ::Gitlab::Routing.url_helpers.subscription_portal_manage_url,
      billable_seats_href: billable_seats_href(namespace),
      plan_name: plan&.name,
      read_only: read_only.to_s,
      seats_last_updated: seats_last_updated_value(namespace)
    }.tap do |attrs|
      if Feature.enabled?(:refresh_billings_seats, type: :ops)
        attrs[:refresh_seats_href] = refresh_seats_group_billings_url(namespace)
      end
    end
  end

  def plan_feature_list(plan)
    plans_features[plan.code] || []
  end

  def plan_purchase_or_upgrade_url(group, plan)
    if group.upgradable?
      plan_upgrade_url(group, plan)
    else
      plan_purchase_url(group, plan)
    end
  end

  def show_plans?(namespace)
    if namespace.free_personal?
      false
    elsif namespace.trial_active?
      true
    else
      !highest_tier?(namespace)
    end
  end

  def upgrade_button_css_classes(namespace, plan, is_current_plan)
    css_classes = []

    css_classes << 'disabled' if is_current_plan && !namespace.trial_active?
    css_classes << 'invisible' if plan.deprecated?
    css_classes << "billing-cta-purchase#{'-new' unless namespace.upgradable?}"

    css_classes.join(' ')
  end

  def billing_available_plans(plans_data, current_plan)
    plans_data.reject do |plan_data|
      if plan_data.code == current_plan&.code
        plan_data.deprecated? && plan_data.hide_deprecated_card?
      else
        plan_data.deprecated?
      end
    end
  end

  def plan_purchase_url(group, plan)
    GitlabSubscriptions::PurchaseUrlBuilder.new(
      plan_id: plan.id,
      namespace: group
    ).build(source: params[:source])
  end

  def billing_upgrade_button_data(plan)
    {
      track_action: 'click_button',
      track_label: 'upgrade',
      track_property: plan.code,
      testid: "upgrade-to-#{plan.code}"
    }
  end

  def add_namespace_plan_to_group_instructions
    link_end = '</a>'.html_safe
    move_link_url = help_page_path 'user/project/working_with_projects.md', anchor: "transfer-a-project"
    move_link_start = '<a href="%{url}" target="_blank" rel="noopener noreferrer">'.html_safe % { url: move_link_url }

    if current_user.owned_or_maintainers_groups.any?
      ERB::Util.html_escape_once(
        s_("BillingPlans|Then %{move_link_start}move any projects%{move_link_end} you wish to use with your subscription to that group.")
      ).html_safe % {
        move_link_start: move_link_start,
        move_link_end: link_end
      }
    else
      create_group_link_url = new_group_path anchor: "create-group-pane"
      create_group_link_start = '<a href="%{url}">'.html_safe % { url: create_group_link_url }

      ERB::Util.html_escape_once(
        s_("BillingPlans|You don't have any groups. You'll need to %{create_group_link_start}create one%{create_group_link_end} and %{move_link_start}move your projects to it%{move_link_end}.")
      ).html_safe % {
        create_group_link_start: create_group_link_start,
        create_group_link_end: link_end,
        move_link_start: move_link_start,
        move_link_end: link_end
      }
    end
  end

  def trusted_by_logos
    [
      { name: 'T-Mobile', path: 'marketing/t-mobile.svg' },
      { name: 'Goldman Sachs', path: 'marketing/goldman-sachs.svg' },
      { name: 'Airbus', path: 'marketing/airbus.svg' },
      { name: 'Lockheed Martin', path: 'marketing/lockheed-martin.svg' },
      { name: 'Carfax', path: 'marketing/carfax.svg', no_invert: true },
      { name: 'NVIDIA', path: 'marketing/nvidia.svg' },
      { name: 'UBS', path: 'marketing/ubs.svg' }
    ]
  end

  private

  def seats_last_updated_value(namespace)
    subscription = namespace.gitlab_subscription

    return unless subscription
    return unless subscription.last_seat_refresh_at

    namespace.gitlab_subscription.last_seat_refresh_at.utc.strftime('%H:%M:%S')
  end

  def add_seats_url(group)
    return unless group

    ::Gitlab::Routing.url_helpers.subscription_portal_add_extra_seats_url(group.id)
  end

  def duo_pro_url(group)
    return unless group

    ::Gitlab::Routing.url_helpers.subscription_portal_add_saas_duo_pro_seats_url(group.id)
  end

  def plan_upgrade_url(group, plan)
    return unless group && plan&.id

    ::Gitlab::Routing.url_helpers.subscription_portal_upgrade_subscription_url(group.id, plan.id)
  end

  def plan_renew_url(group)
    return unless group

    ::Gitlab::Routing.url_helpers.subscription_portal_renew_subscription_url(group.id)
  end

  def billable_seats_href(namespace)
    return unless namespace.group_namespace?

    group_usage_quotas_path(namespace, anchor: 'seats-quota-tab')
  end

  def highest_tier?(namespace)
    namespace.gold_plan? || namespace.ultimate_plan? || namespace.opensource_plan?
  end

  def plans_features
    Hashie::Mash.new({
      free: [
        { title: s_('BillingPlans|Includes'), highlight: true },
        { title: s_('BillingPlans|All stages of the DevOps lifecycle') },
        { title: s_('BillingPlans|Bring your own CI runners') },
        { title: s_('BillingPlans|Bring your own production environment') },
        { title: s_('BillingPlans|400 compute minutes') }
      ],
      premium: [
        { title: s_('BillingPlans|All the benefits of Free +'), highlight: true },
        { title: s_('BillingPlans|Cross-team project management') },
        { title: s_('BillingPlans|Multiple approval rules') },
        { title: s_('BillingPlans|Multi-region support') },
        { title: s_('BillingPlans|Priority support') },
        { title: s_('BillingPlans|10000 compute minutes') }
      ],
      ultimate: [
        { title: s_('BillingPlans|All the benefits of Premium +'), highlight: true },
        { title: s_('BillingPlans|Company wide portfolio management') },
        { title: s_('BillingPlans|Advanced application security') },
        { title: s_('BillingPlans|Executive level insights') },
        { title: s_('BillingPlans|Compliance automation') },
        { title: s_('BillingPlans|Free guest users') },
        { title: s_('BillingPlans|50000 compute minutes') }
      ]
    })
  end
  strong_memoize_attr :plans_features
end

BillingPlansHelper.prepend_mod
