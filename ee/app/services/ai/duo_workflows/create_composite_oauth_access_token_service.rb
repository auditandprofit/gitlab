# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class CreateCompositeOauthAccessTokenService
      include ::Services::ReturnServiceResponses
      include ::Gitlab::Utils::StrongMemoize

      CompositeIdentityEnforcedError = Class.new(StandardError)
      IncompleteOnboardingError = Class.new(StandardError)

      def initialize(current_user:, organization:)
        @current_user = current_user
        @organization = organization
      end

      def execute
        unless Feature.enabled?(
          :duo_workflow_in_ci, @current_user)
          return ServiceResponse.error(message: 'Can not generate token to execute workflow in CI',
            reason: :feature_unavailable)
        end

        ensure_onboarding_complete!
        token = create_oauth_access_token
        success(oauth_access_token: token)
      end

      private

      def create_oauth_access_token
        OauthAccessToken.create!(
          application_id: ai_settings.duo_workflow_oauth_application_id,
          expires_in: 1.hour,
          resource_owner_id: ai_settings.duo_workflow_service_account_user_id,
          organization: @organization,
          scopes: ::Gitlab::Auth::AI_WORKFLOW_SCOPES + dynamic_user_scope
        )
      end

      def ensure_onboarding_complete!
        if ai_settings.duo_workflow_service_account_user.nil? || ai_settings.duo_workflow_oauth_application.nil?
          raise IncompleteOnboardingError,
            'Duo Workflow onboarding is incomplete. Please complete onboarding to proceed further.'
        elsif !ai_settings.duo_workflow_service_account_user.composite_identity_enforced?
          raise CompositeIdentityEnforcedError,
            'The Duo Workflow service account must have composite identity enabled.'
        end
      end

      def dynamic_user_scope
        ["user:#{@current_user.id}"]
      end

      def ai_settings
        Ai::Setting.instance
      end
      strong_memoize_attr :ai_settings
    end
  end
end
