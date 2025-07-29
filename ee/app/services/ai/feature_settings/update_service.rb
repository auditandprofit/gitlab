# frozen_string_literal: true

module Ai
  module FeatureSettings
    class UpdateService
      def initialize(feature_setting, user, params)
        @feature_setting = feature_setting
        @user = user
        @params = params
      end

      def execute
        if feature_setting.update(@params)
          audit_event

          ServiceResponse.success(payload: feature_setting)
        else
          ServiceResponse.error(payload: feature_setting, message: feature_setting.errors.full_messages.join(", "))
        end
      end

      private

      attr_accessor :feature_setting, :user

      def audit_event
        audit_context = {
          name: 'self_hosted_model_feature_changed',
          author: user,
          scope: Gitlab::Audit::InstanceScope.new,
          target: feature_setting,
          message: "Feature #{feature_setting.feature} changed to #{feature_setting.provider_title}"
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end
    end
  end
end
