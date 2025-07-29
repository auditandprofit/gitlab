# frozen_string_literal: true

module EE
  module Gitlab
    module PersonalAccessTokens
      class ServiceAccountTokenValidator
        def initialize(service_account_user)
          @service_account_user = service_account_user
        end

        attr_accessor :service_account_user

        def expiry_enforced?
          unless License.feature_available?(:service_accounts) && service_account_user.service_account?
            return ::Gitlab::CurrentSettings.require_personal_access_token_expiry?
          end

          if saas?
            return true unless service_account_scoped_to_group

            return service_account_user.provisioned_by_group
            .namespace_settings.service_access_tokens_expiration_enforced
          end

          ::Gitlab::CurrentSettings.current_application_settings.service_access_tokens_expiration_enforced
        end

        def saas?
          ::Gitlab::Saas.enabled?
        end

        def service_account_scoped_to_group
          service_account_user.provisioned_by_group.present?
        end
      end
    end
  end
end
