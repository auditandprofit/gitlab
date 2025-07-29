# frozen_string_literal: true

module API
  class ProjectSecuritySettings < ::API::Base
    before { authenticate! }
    before { check_feature_availability }

    helpers do
      def check_feature_availability
        forbidden! unless ::License.feature_available?(:secret_push_protection)
      end
    end

    feature_category :secret_detection

    params do
      requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the project'
    end

    resource :projects, requirements: ::API::API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      segment ':id/security_settings' do
        desc 'Get project security settings' do
          detail 'Returns a JSON object of the project security setting'
          tags %w[projects]
        end
        get do
          unauthorized! unless can?(current_user, :read_security_settings, user_project)

          present user_project&.security_setting
        end

        desc 'Update project security settings' do
          detail 'Updates secret_push_protection_enabled to the new value & returns new project security setting'
          tags %w[projects]
        end
        params do
          optional :secret_push_protection_enabled, type: Boolean, desc: 'Enable/disable secret push protection'
          optional :pre_receive_secret_detection_enabled, type: Boolean, desc: 'Enable/disable secret push protection'
          at_least_one_of :secret_push_protection_enabled, :pre_receive_secret_detection_enabled
        end
        put do
          unauthorized! unless can?(current_user, :manage_security_settings, user_project)

          enabled = if params.key?(:secret_push_protection_enabled)
                      params[:secret_push_protection_enabled]
                    else
                      params[:pre_receive_secret_detection_enabled]
                    end

          audit_context = {
            name: 'project_security_setting_updated',
            author: current_user,
            target: user_project,
            scope: user_project,
            message: "User #{current_user.name} updated `secret_push_protection_enabled` to #{enabled}"
          }

          ::Gitlab::Audit::Auditor.audit(audit_context)
          security_setting = user_project&.security_setting
          security_setting.set_secret_push_protection!(enabled: enabled)
          present security_setting
        end
      end
    end
  end
end
