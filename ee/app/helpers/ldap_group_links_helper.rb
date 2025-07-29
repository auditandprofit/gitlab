# frozen_string_literal: true

module LdapGroupLinksHelper
  def ldap_group_link_input_names
    {
      base_access_level_input_name: "ldap_group_link[group_access]",
      member_role_id_input_name: "ldap_group_link[member_role_id]"
    }
  end
end
