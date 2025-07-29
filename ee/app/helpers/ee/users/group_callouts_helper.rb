# frozen_string_literal: true

module EE
  module Users
    module GroupCalloutsHelper
      ALL_SEATS_USED_ALERT = 'all_seats_used_alert'
      COMPLIANCE_FRAMEWORK_SETTINGS_MOVED_CALLOUT = 'compliance_framework_settings_moved_callout'

      def show_compliance_framework_settings_moved_callout?(group)
        !user_dismissed_for_group(COMPLIANCE_FRAMEWORK_SETTINGS_MOVED_CALLOUT, group)
      end

      def show_enable_duo_banner?(group, callouts_feature_name)
        ::Gitlab::Saas.feature_available?(:gitlab_duo_saas_only) &&
          Ability.allowed?(current_user, :admin_group, group) &&
          group.namespace_settings.duo_core_features_enabled.nil? &&
          !user_dismissed_for_group(callouts_feature_name, group) &&
          GitlabSubscriptions::DuoCore.any_add_on_purchase_for_namespace?(group) &&
          group.paid? && !group.trial?
      end
    end
  end
end
