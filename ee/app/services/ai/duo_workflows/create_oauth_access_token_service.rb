# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class CreateOauthAccessTokenService
      include ::Services::ReturnServiceResponses

      def initialize(current_user:, organization:, workflow_definition: nil)
        @current_user = current_user
        @organization = organization
        @workflow_definition = workflow_definition
      end

      def execute
        return error('Duo workflow is not enabled for user', :forbidden) if feature_disabled_for_user?

        ensure_oauth_application!
        token = create_oauth_access_token
        success(oauth_access_token: token)
      end

      private

      attr_reader :current_user

      def create_oauth_access_token
        # OAuth tokens are hashed before being saved in the database, so we must
        # re-create them each time to retrieve the plaintext value
        # see https://gitlab.com/gitlab-org/gitlab/-/merge_requests/91501
        OauthAccessToken.create!(
          application_id: oauth_application.id,
          expires_in: 2.hours,
          resource_owner_id: current_user.id,
          organization: @organization,
          scopes: oauth_application.scopes.to_s
        )
      end

      def ensure_oauth_application!
        return if oauth_application

        should_expire_cache = false

        application_settings.with_lock do
          # note: `with_lock` busts application_settings cache and will trigger another query.
          # We need to double check here so that requests previously waiting on the lock can
          # now just skip.
          next if oauth_application

          application = Doorkeeper::Application.new(
            name: 'GitLab Duo Workflow',
            redirect_uri: oauth_callback_url,
            scopes: ::Gitlab::Auth::AI_WORKFLOW_SCOPES,
            trusted: true,
            confidential: false
          )
          application.save!
          application_settings.update!(duo_workflow: { duo_workflow_oauth_application_id: application.id })
          should_expire_cache = true
        end

        # note: This needs to happen outside the transaction, but only if we actually changed something
        ::Gitlab::CurrentSettings.expire_current_application_settings if should_expire_cache
      end

      def application_settings
        ::Gitlab::CurrentSettings.current_application_settings
      end

      def oauth_application
        oauth_application_id = application_settings.duo_workflow_oauth_application_id
        return unless oauth_application_id

        Doorkeeper::Application.find(oauth_application_id)
      end

      def oauth_callback_url
        # This value is unused but cannot be nil
        Gitlab::Routing.url_helpers.root_url
      end

      def feature_disabled_for_user?
        case @workflow_definition
        when nil
          Feature.disabled?(:duo_workflow, current_user) && Feature.disabled?(:duo_agentic_chat, current_user)
        when "chat"
          Feature.disabled?(:duo_agentic_chat, current_user)
        else
          Feature.disabled?(:duo_workflow, current_user)
        end
      end
    end
  end
end
