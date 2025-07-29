# frozen_string_literal: true

module EE
  module API
    module Helpers
      module GroupsHelpers
        extend ActiveSupport::Concern

        prepended do
          params :optional_params_ee do
            optional :membership_lock, type: ::Grape::API::Boolean, desc: 'Prevent adding new members to projects within this group'
            optional :ldap_cn, type: String, desc: 'LDAP Common Name'
            optional :ldap_access, type: Integer, desc: 'A valid access level'
            optional :shared_runners_minutes_limit, type: Integer, desc: '(admin-only) compute minutes quota for this group'
            optional :extra_shared_runners_minutes_limit, type: Integer, desc: '(admin-only) Extra compute minutes quota for this group'
            optional :wiki_access_level, type: String, values: %w[disabled private enabled], desc: 'Wiki access level. One of `disabled`, `private` or `enabled`'
            optional :duo_availability, type: String, values: %w[default_on default_off never_on], desc: 'Duo availability. One of `default_on`, `default_off` or `never_on`'
            optional :amazon_q_auto_review_enabled, type: ::Grape::API::Boolean, desc: 'Enable Amazon Q auto review for merge request'
            optional :experiment_features_enabled, type: ::Grape::API::Boolean, desc: 'Enable experiment features for this group'
            optional :model_prompt_cache_enabled, type: ::Grape::API::Boolean, desc: 'Enable model prompt cache for this group'
            optional :ai_settings_attributes, type: Hash, desc: 'AI-related settings' do
              optional :duo_workflow_mcp_enabled, type: ::Grape::API::Boolean, desc: 'Enable MCP support for Duo Workflow'
            end
            all_or_none_of :ldap_cn, :ldap_access
          end

          params :optional_update_params_ee do
            optional :file_template_project_id,
              type: Integer, desc: 'The ID of a project to use for custom templates in this group'
            optional :prevent_forking_outside_group,
              type: ::Grape::API::Boolean, desc: 'Prevent forking projects inside this group to external namespaces'
            optional :unique_project_download_limit,
              type: Integer,
              desc: 'Maximum number of unique projects a user can download in the specified time period before they ' \
                    'are banned.'
            optional :unique_project_download_limit_interval_in_seconds,
              type: Integer,
              desc: 'Time period during which a user can download a maximum amount of projects before they are banned.'
            optional :unique_project_download_limit_allowlist,
              type: Array[String],
              coerce_with: ::API::Validations::Types::CommaSeparatedToArray.coerce,
              desc: 'List of usernames excluded from the unique project download limit'
            optional :unique_project_download_limit_alertlist,
              type: Array[Integer],
              desc: 'List of user ids who will be emailed when Git abuse rate limit is exceeded'
            optional :auto_ban_user_on_excessive_projects_download,
              type: Grape::API::Boolean,
              desc: 'Ban users from the group when they exceed maximum number of unique projects download in the specified time period'
            optional :ip_restriction_ranges,
              type: String,
              desc: 'List of IP addresses which need to be restricted for group'
            optional :allowed_email_domains_list,
              type: String,
              desc: 'List of allowed email domains for group'
            optional :service_access_tokens_expiration_enforced,
              type: ::Grape::API::Boolean,
              desc: "To enforce token expiration for Service accounts users for group"
            optional :duo_core_features_enabled,
              type: ::Grape::API::Boolean,
              desc: '[Experimental] Indicates whether GitLab Duo Core features are enabled for the group'
            optional :duo_features_enabled,
              type: ::Grape::API::Boolean,
              desc: "Indicates whether GitLab Duo features are enabled for the group"
            optional :lock_duo_features_enabled,
              type: ::Grape::API::Boolean,
              desc: "Indicates if the GitLab Duo features enabled setting is enforced for all subgroups"
            optional :web_based_commit_signing_enabled,
              type: ::Grape::API::Boolean,
              desc: 'Enable web based commit signing for this group'
          end

          params :optional_projects_params_ee do
            optional :with_security_reports, type: ::Grape::API::Boolean, default: false, desc: 'Return only projects having security report artifacts present'
          end

          params :optional_group_list_params_ee do
            optional :repository_storage, type: String, desc: 'Filter by repository storage used by the group'
          end
        end
      end
    end
  end
end
