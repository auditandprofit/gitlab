import SamlSettingsForm from 'ee/saml_providers/saml_settings_form';
import initSamlMembershipRoleSelector from 'ee/saml_providers/saml_membership_role_selector';

initSamlMembershipRoleSelector();

export default function initSAML() {
  new SamlSettingsForm('#js-saml-settings-form').init();
}
