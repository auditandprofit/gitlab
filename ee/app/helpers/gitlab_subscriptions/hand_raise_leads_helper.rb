# frozen_string_literal: true

module GitlabSubscriptions
  module HandRaiseLeadsHelper
    def hand_raise_modal_dataset(root_namespace)
      {
        user: {
          namespace_id: root_namespace.id,
          user_name: current_user.username,
          first_name: current_user.first_name,
          last_name: current_user.last_name,
          company_name: current_user.user_detail_organization
        }.to_json,
        submit_path: gitlab_subscriptions_hand_raise_leads_path
      }
    end

    def discover_page_hand_raise_lead_data(group)
      {
        glm_content: 'trial_discover_page',
        cta_tracking: {
          action: 'click_contact_sales',
          label: group_trial_status(group)
        }.to_json,
        button_attributes: {
          variant: 'confirm',
          category: 'secondary',
          'data-testid': 'trial-discover-hand-raise-lead-button',
          class: 'gl-w-full sm:gl-w-auto'
        }.to_json
      }
    end

    def free_plan_billing_hand_raise_lead_data
      {
        glm_content: 'billing-group',
        button_text: s_("BillingPlans|Talk to an expert"),
        button_attributes: { category: 'secondary', class: 'gl-align-text-bottom' }.to_json,
        cta_tracking: {
          action: 'click_button'
        }.to_json
      }
    end

    def billing_action_hand_raise_lead_data(plan_code)
      {
        glm_content: 'billing-group',
        cta_tracking: {
          action: 'click_link',
          property: plan_code
        }.to_json,
        button_attributes: {}.to_json
      }
    end

    def discover_duo_pro_hand_raise_lead_data(namespace)
      {
        namespace_id: namespace.id,
        glm_content: 'discover-duo-pro',
        cta_tracking: {
          action: 'click_contact_sales',
          label: duo_pro_trial_status_cta_label(namespace)
        }.to_json,
        button_attributes: {
          category: 'secondary',
          variant: 'confirm',
          class: 'gl-w-full sm:gl-w-auto'
        }.to_json
      }
    end

    def code_suggestions_usage_app_hand_raise_lead_data
      {
        glm_content: 'code-suggestions',
        product_interaction: 'Requested Contact-Duo Pro Add-On',
        button_attributes: {
          'data-testid': 'code-suggestions-hand-raise-lead-button',
          category: 'secondary',
          variant: 'confirm',
          class: 'sm:gl-w-auto gl-w-full sm:gl-ml-3 sm:gl-mt-0 gl-mt-3'
        }.to_json,
        cta_tracking: {
          action: 'click_button',
          label: 'code_suggestions_hand_raise_lead_form'
        }.to_json
      }
    end

    def group_trial_status(group)
      strong_memoize_with(:group_trial_status, group) do
        group.trial_active? ? 'trial_active' : 'trial_expired'
      end
    end

    def duo_pro_trial_status_cta_label(namespace)
      if GitlabSubscriptions::Trials::DuoPro.active_add_on_purchase_for_namespace?(namespace)
        'duo_pro_active_trial'
      else
        'duo_pro_expired_trial'
      end
    end
  end
end
