# frozen_string_literal: true

module Ai
  module DuoWorkflow
    class << self
      def enabled?
        return false unless License.feature_available?(:ai_workflows)

        duo_features_enabled?
      end

      def connected?
        return false unless enabled?

        ai_settings.duo_workflow_service_account_user.present? && ai_settings.duo_workflow_oauth_application.present?
      end

      def available?
        return false unless connected?

        service_account = ai_settings.duo_workflow_service_account_user
        return false if service_account.blocked? || !service_account.composite_identity_enforced

        oauth_app = ai_settings.duo_workflow_oauth_application

        return false unless oauth_app.scopes.to_s.include?(::Gitlab::Auth::DYNAMIC_USER.to_s)

        true
      end

      def ensure_service_account_blocked!(current_user:, service_account: nil)
        service_account ||= ai_settings.duo_workflow_service_account_user

        return ServiceResponse.success(message: 'Service account not found. Nothing to do.') unless service_account

        if service_account.blocked?
          return ServiceResponse.success(message: 'Service account already blocked. Nothing to do.')
        end

        result = ::Users::BlockService.new(current_user).execute(service_account)
        ServiceResponse.from_legacy_hash(result)
      end

      def ensure_service_account_unblocked!(current_user:, service_account: nil)
        service_account ||= ai_settings.duo_workflow_service_account_user

        return ServiceResponse.error(message: 'Service account not found.') unless service_account

        unless service_account.blocked?
          return ServiceResponse.success(message: 'Service account already unblocked. Nothing to do.')
        end

        result = ::Users::UnblockService.new(current_user).execute(service_account)
        ServiceResponse.from_legacy_hash(result)
      end

      private

      def ai_settings
        Ai::Setting.instance
      end

      def duo_features_enabled?
        ::Gitlab::CurrentSettings.current_application_settings.duo_features_enabled
      end
    end
  end
end
