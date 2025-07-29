# frozen_string_literal: true

module API
  class GroupSecuritySettings < ::API::Base
    feature_category :security_testing_configuration

    before do
      authenticate!
      check_feature_availability
    end

    helpers do
      def check_feature_availability
        forbidden! unless ::License.feature_available?(:secret_push_protection)
      end
    end

    params do
      requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the group'
    end

    resource :groups, requirements: ::API::API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      segment ':id/security_settings' do
        desc 'Update group security settings' do
          detail 'Updates secret_push_protection_enabled for all projects to the new value'
          tags %w[groups]
        end
        params do
          requires :secret_push_protection_enabled, type: Boolean,
            desc: 'Whether to enable the feature'
          optional :projects_to_exclude, type: Array[Integer], desc: 'IDs of projects to exclude from the feature'
        end
        put do
          unauthorized! unless can?(current_user, :enable_secret_push_protection, user_group)

          enabled = params[:secret_push_protection_enabled]
          projects_to_exclude = params[:projects_to_exclude]

          ::Security::Configuration::SetGroupSecretPushProtectionWorker.perform_async(user_group.id, enabled, current_user.id, projects_to_exclude) # rubocop:disable CodeReuse/Worker -- This is meant to be a background job

          {
            secret_push_protection_enabled: enabled,
            errors: []
          }
        end
      end
    end
  end
end
