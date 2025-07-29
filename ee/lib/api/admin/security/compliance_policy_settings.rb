# frozen_string_literal: true

module API
  module Admin
    module Security
      class CompliancePolicySettings < ::API::Base
        before { authenticated_as_admin! }

        feature_category :security_policy_management
        urgency :low

        helpers do
          def ensure_licensed!
            return if ::License.feature_available?(:security_orchestration_policies)

            forbidden!('security_orchestration_policies license feature not available')
          end

          def ensure_feature_enabled!
            return if ::Feature.enabled?(:security_policies_csp, :instance)

            bad_request!('feature flag security_policies_csp is not enabled')
          end

          def policy_setting
            @policy_setting ||= ::Security::PolicySetting.for_organization(
              ::Organizations::Organization.default_organization
            )
          end
        end

        namespace 'admin' do
          namespace 'security' do
            resource :compliance_policy_settings do
              desc 'Get security policy settings' do
                detail 'Retrieve the current security policy settings'
                success ::API::Entities::Admin::Security::PolicySetting
                failure [
                  { code: 401, message: '401 Unauthorized' },
                  { code: 403, message: '403 Forbidden' },
                  { code: 400, message: '400 Bad Request' }
                ]
              end
              get do
                ensure_licensed!
                ensure_feature_enabled!

                present policy_setting, with: ::API::Entities::Admin::Security::PolicySetting
              end

              desc 'Update security policy settings' do
                detail 'Update the security policy settings'
                success ::API::Entities::Admin::Security::PolicySetting
                failure [
                  { code: 401, message: '401 Unauthorized' },
                  { code: 403, message: '403 Forbidden' },
                  { code: 400, message: '400 Bad Request' },
                  { code: 422, message: '422 Unprocessable Entity' }
                ]
              end
              params do
                requires :csp_namespace_id,
                  type: Integer,
                  desc: 'ID of the group designated to centrally manage security policies and compliance frameworks.'
              end
              put do
                ensure_licensed!
                ensure_feature_enabled!

                if policy_setting.update(declared_params)
                  present policy_setting, with: ::API::Entities::Admin::Security::PolicySetting
                else
                  unprocessable_entity!(policy_setting.errors.full_messages.join(', '))
                end
              end
            end
          end
        end
      end
    end
  end
end
