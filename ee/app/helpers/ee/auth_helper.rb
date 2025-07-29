# frozen_string_literal: true

module EE
  module AuthHelper
    extend ::Gitlab::Utils::Override

    PROVIDERS_WITH_ICONS = %w[
      kerberos
    ].freeze
    GROUP_LEVEL_PROVIDERS = %i[group_saml].freeze

    override :display_providers_on_profile?
    def display_providers_on_profile?
      super || group_saml_enabled?
    end

    override :button_based_providers
    def button_based_providers
      super - GROUP_LEVEL_PROVIDERS
    end

    override :providers_for_base_controller
    def providers_for_base_controller
      super - GROUP_LEVEL_PROVIDERS
    end

    override :provider_has_builtin_icon?
    def provider_has_builtin_icon?(name)
      super || PROVIDERS_WITH_ICONS.include?(name.to_s)
    end

    override :form_based_provider_priority
    def form_based_provider_priority
      super << 'smartcard'
    end

    override :form_based_providers
    def form_based_providers
      providers = super

      providers << :smartcard if smartcard_enabled?

      providers
    end

    def password_rule_list(basic)
      if ::License.feature_available?(:password_complexity)
        rules = []
        rules.concat([:length, :common, :user_info]) if basic
        rules << :number if ::Gitlab::CurrentSettings.password_number_required?
        rules << :lowercase if ::Gitlab::CurrentSettings.password_lowercase_required?
        rules << :uppercase if ::Gitlab::CurrentSettings.password_uppercase_required?
        rules << :symbol if ::Gitlab::CurrentSettings.password_symbol_required?

        rules
      end
    end

    def google_tag_manager_enabled?
      return false unless ::Gitlab::Saas.feature_available?(:marketing_google_tag_manager)

      extra_config.has_key?('google_tag_manager_nonce_id') &&
        extra_config.google_tag_manager_nonce_id.present?
    end

    def google_tag_manager_id
      return unless google_tag_manager_enabled?

      extra_config.google_tag_manager_nonce_id
    end

    def kerberos_enabled?
      auth_providers.include?(:kerberos)
    end

    def smartcard_enabled?
      ::Gitlab::Auth::Smartcard.enabled?
    end

    def smartcard_enabled_for_ldap?(provider_name, required: false)
      return false unless smartcard_enabled?

      server = ::Gitlab::Auth::Ldap::Config.servers.find do |server|
        server['provider_name'] == provider_name
      end

      return false unless server

      truthy_values = ['required']
      truthy_values << 'optional' unless required

      truthy_values.include? server['smartcard_auth']
    end

    def smartcard_login_button_category(provider_name)
      return :secondary unless smartcard_enabled_for_ldap?(provider_name, required: true)

      :primary
    end

    def group_saml_enabled?
      auth_providers.include?(:group_saml)
    end

    def saml_group_sync_enabled?
      return true if group_saml_enabled?

      saml_providers.any? do |provider|
        ::Gitlab::Auth::Saml::Config.new(provider).group_sync_enabled?
      end
    end

    def expires_at_for_service_access_tokens(enforce_expiration)
      return expires_at_field_data if enforce_expiration

      {
        min_date: 1.day.from_now.iso8601
      }
    end

    def admin_service_accounts_data(user = current_user)
      sources = scope_description(:personal_access_token)
      scopes = ::Gitlab::Auth.available_scopes_for(user)
      {
        base_path: admin_application_settings_service_accounts_path,
        is_group: false.to_s,
        service_accounts: {
          path: expose_url(api_v4_service_accounts_path),
          edit_path: expose_url(api_v4_service_accounts_path),
          docs_path: help_page_path('user/profile/service_accounts.md'),
          delete_path: expose_url(api_v4_users_path)
        },
        access_token: {
          **expires_at_for_service_access_tokens(
            ::Gitlab::CurrentSettings.current_application_settings.service_access_tokens_expiration_enforced
          ),
          available_scopes: filter_sort_scopes(scopes, sources).to_json,
          create: expose_url(api_v4_users_personal_access_tokens_path(user_id: ':id')),
          revoke: expose_url(api_v4_personal_access_tokens_path),
          rotate: expose_url(api_v4_personal_access_tokens_path),
          show: "#{expose_url(api_v4_personal_access_tokens_path)}?user_id=:id"
        }
      }
    end

    def groups_service_accounts_data(group, user = current_user)
      sources = scope_description(:personal_access_token)
      scopes = ::Gitlab::Auth.available_scopes_for(user)
      {
        base_path: group_settings_service_accounts_path(group),
        is_group: true.to_s,
        service_accounts: {
          path: expose_url(api_v4_groups_service_accounts_path(id: group.id)),
          edit_path: expose_url(api_v4_groups_service_accounts_path(id: group.id)),
          docs_path: help_page_path('user/profile/service_accounts.md'),
          delete_path: expose_url(api_v4_groups_service_accounts_path(id: group.id))
        },
        access_token: {
          **expires_at_for_service_access_tokens(group.namespace_settings.service_access_tokens_expiration_enforced),
          available_scopes: filter_sort_scopes(scopes, sources).to_json,
          create: expose_url(api_v4_groups_service_accounts_personal_access_tokens_path(id: group.id, user_id: ':id')),
          revoke: expose_url(api_v4_groups_service_accounts_personal_access_tokens_path(id: group.id, user_id: ':id')),
          rotate: expose_url(api_v4_groups_service_accounts_personal_access_tokens_path(id: group.id, user_id: ':id')),
          show: expose_url(api_v4_groups_service_accounts_personal_access_tokens_path(id: group.id, user_id: ':id'))
        }
      }
    end
  end
end
