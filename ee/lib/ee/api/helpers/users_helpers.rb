# frozen_string_literal: true

module EE
  module API
    module Helpers
      module UsersHelpers
        extend ActiveSupport::Concern

        prepended do
          params :optional_params_ee do
            optional :shared_runners_minutes_limit, type: Integer, desc: 'Compute minutes quota for this user'
            optional :extra_shared_runners_minutes_limit, type: Integer, desc: '(admin-only) Extra compute minutes quota for this user'
            optional :group_id_for_saml, type: Integer, desc: 'ID for group where SAML has been configured'
            optional :auditor, type: Grape::API::Boolean, desc: 'Flag indicating auditor status of the user'
          end

          params :optional_index_params_ee do
            optional :skip_ldap, type: Grape::API::Boolean, default: false, desc: 'Skip LDAP users'
            optional :auditors, type: Grape::API::Boolean, default: false, desc: 'Filters only auditor users'
          end

          def error_for_saml_provider_id_param_ee
            return unless params[:saml_provider_id].present?

            forbidden!(
              "saml_provider_id attribute was removed for security reasons. " \
                "Consider using 'GET /groups/:id/saml_users' API endpoint instead, " \
                "see #{Rails.application.routes.url_helpers.help_page_url('api/groups.md', anchor: 'list-all-saml-users')}"
            )
          end
        end
      end
    end
  end
end
