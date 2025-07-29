# frozen_string_literal: true

module Ai
  class Setting < ApplicationRecord
    self.table_name = "ai_settings"

    include SingletonRecord

    ignore_column :duo_nano_features_enabled, remove_with: '18.3', remove_after: '2025-07-15'

    validates :ai_gateway_url, length: { maximum: 2048 }, allow_nil: true
    validates :amazon_q_role_arn, length: { maximum: 2048 }, allow_nil: true

    validate :validate_ai_gateway_url

    validates :duo_core_features_enabled,
      inclusion: { in: [true, false] },
      if: :will_save_change_to_duo_core_features_enabled?

    belongs_to :amazon_q_oauth_application, class_name: 'Doorkeeper::Application', optional: true
    belongs_to :amazon_q_service_account_user, class_name: 'User', optional: true

    belongs_to :duo_workflow_oauth_application, class_name: 'Doorkeeper::Application', optional: true
    belongs_to :duo_workflow_service_account_user, class_name: 'User', optional: true

    after_commit :trigger_todo_creation, on: :update, if: :saved_change_to_duo_core_features_enabled?

    def self.defaults
      {
        ai_gateway_url: ENV['AI_GATEWAY_URL'],
        enabled_instance_verbose_ai_logs: Feature.enabled?(:expanded_ai_logging) # rubocop:disable Gitlab/FeatureFlagWithoutActor -- this is an instance level FF
      }
    end

    def self.self_hosted?
      ::Ai::SelfHostedModel.any?
    end

    def self.duo_core_features_enabled?
      !!instance.duo_core_features_enabled
    end

    private

    def trigger_todo_creation
      return if ::Gitlab::Saas.feature_available?(:gitlab_duo_saas_only)
      return unless duo_core_features_enabled?

      GitlabSubscriptions::SelfManaged::DuoCoreTodoNotificationWorker
        .perform_in(GitlabSubscriptions::DuoCore::DELAY_TODO_NOTIFICATION)
    end

    def validate_ai_gateway_url
      return if ai_gateway_url.blank?

      begin
        Gitlab::HTTP_V2::UrlBlocker.validate!(
          ai_gateway_url,
          schemes: %w[http https],
          allow_localhost: allow_localhost,
          enforce_sanitization: true,
          deny_all_requests_except_allowed: Gitlab::CurrentSettings.deny_all_requests_except_allowed?,
          outbound_local_requests_allowlist: Gitlab::CurrentSettings.outbound_local_requests_whitelist # rubocop:disable Naming/InclusiveLanguage -- existing setting
        )
      rescue Gitlab::HTTP_V2::UrlBlocker::BlockedUrlError => e
        errors.add(:ai_gateway_url, e.message)
      end
    end

    def allow_localhost
      return true if Gitlab.dev_or_test_env?

      false
    end
  end
end
