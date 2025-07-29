# frozen_string_literal: true

module SamlGroupLinksHelper
  def saml_group_link_input_names
    {
      base_access_level_input_name: "saml_group_link[access_level]",
      member_role_id_input_name: "saml_group_link[member_role_id]"
    }
  end

  # For SaaS only. Self-managed configures add-on groups in the configuration file.
  def duo_seat_assignment_available?(group)
    return false unless ::Gitlab::Saas.feature_available?(:gitlab_duo_saas_only)
    return false if group.has_parent?

    add_on_purchase = GitlabSubscriptions::Duo.enterprise_or_pro_for_namespace(group)
    return false unless add_on_purchase.present?

    add_on_purchase.active?
  end

  def multiple_saml_providers?
    saml_providers.count > 1
  end

  def saml_providers_for_dropdown
    saml_providers.map { |provider| [Gitlab::Auth::OAuth::Provider.label_for(provider), provider.to_s] }
  end
end
