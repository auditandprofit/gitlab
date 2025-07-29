# frozen_string_literal: true

module Namespaces
  module FreeUserCap
    class UnlimitedMembersDuringTrialAlertComponent < ViewComponent::Base
      include SafeFormatHelper

      def initialize(
        namespace:, user:, wrapper_class:, hide_invite_members_button: false, hide_explore_paid_plans_button: false
      )
        @namespace = namespace
        @user = user
        @wrapper_class = wrapper_class
        @hide_invite_members_button = hide_invite_members_button
        @hide_explore_paid_plans_button = hide_explore_paid_plans_button
      end

      private

      attr_reader :namespace, :user, :wrapper_class, :hide_invite_members_button, :hide_explore_paid_plans_button

      use_helpers :current_path?

      def render?
        show_unlimited_members_during_trial_alert?
      end

      def show_unlimited_members_during_trial_alert?
        !Feature.enabled?(:streamlined_first_product_experience, :instance) &&
          ::Namespaces::FreeUserCap::Enforcement.new(namespace).qualified_namespace? &&
          ::Namespaces::FreeUserCap.owner_access?(user: user, namespace: namespace) &&
          namespace.trial_active? &&
          !dismissed_for_namespace &&
          !::Onboarding::Progress.completed?(namespace, :user_added)
      end

      def feature_name
        'unlimited_members_during_trial_alert'
      end

      def variant
        :info
      end

      def alert_attributes
        {
          title: s_('UnlimitedMembersDuringTrialAlert|Get the most out of your trial with space for more members'),
          body: body_text
        }
      end

      def alert_data
        {
          feature_id: feature_name,
          dismiss_endpoint: group_callouts_path,
          group_id: namespace.id,
          testid: 'unlimited-members-during-trial-alert'
        }
      end

      def body_text
        limit = ::Namespaces::FreeUserCap.dashboard_limit

        message = ns_(
          "UnlimitedMembersDuringTrialAlert|During your trial, invite as many members as you like to " \
            "%{name} to collaborate with you. When your trial ends, you'll have a maximum of %{limit} " \
            "member on the Free tier, or you can get more by upgrading to a paid tier.",
          "UnlimitedMembersDuringTrialAlert|During your trial, invite as many members as you like to " \
            "%{name} to collaborate with you. When your trial ends, you'll have a maximum of %{limit} " \
            "members on the Free tier, or you can get more by upgrading to a paid tier.",
          limit
        )

        safe_format(message, name: namespace.name, limit: limit)
      end

      def primary_cta
        if hide_invite_members_button
          render Pajamas::ButtonComponent.new(href: group_billings_path(namespace), variant: :confirm) do
            s_('UnlimitedMembersDuringTrialAlert|Explore paid plans')
          end
        else
          invite_members_button
        end
      end

      def secondary_cta
        return unless render_secondary_cta?

        render Pajamas::ButtonComponent.new(href: group_billings_path(namespace)) do
          s_('UnlimitedMembersDuringTrialAlert|Explore paid plans')
        end
      end

      def invite_members_button
        content_tag(:div, nil, class: 'js-invite-members-trigger', data: {
          variant: :confirm,
          display_text: s_('UnlimitedMembersDuringTrialAlert|Invite more members'),
          trigger_source: 'unlimited_members_during_trial_alert',
          classes: 'gl-mr-3'
        })
      end

      def render_secondary_cta?
        !hide_explore_paid_plans_button && !hide_invite_members_button
      end

      def dismissed_for_namespace
        user.dismissed_callout_for_group?(
          feature_name: feature_name,
          group: namespace
        )
      end

      def close_button_data
        {
          testid: 'hide-unlimited-members-during-trial-alert'
        }
      end

      def dismissible
        true
      end
    end
  end
end
