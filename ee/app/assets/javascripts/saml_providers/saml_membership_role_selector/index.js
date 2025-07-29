import Vue from 'vue';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import SamlMembershipRoleSelector from './components/saml_membership_role_selector.vue';

export default () => {
  const el = document.querySelector('.js-saml-membership-role-selector');

  if (!el) {
    return null;
  }

  const { samlMembershipRoleSelectorData } = el.dataset;
  const {
    standardRoles,
    currentStandardRole,
    customRoles = [],
    currentCustomRoleId,
  } = convertObjectPropsToCamelCase(JSON.parse(samlMembershipRoleSelectorData), { deep: true });

  return new Vue({
    el,
    name: 'SamlMembershipRoleSelectorRoot',
    provide: {
      standardRoles,
      currentStandardRole,
      customRoles,
      currentCustomRoleId,
    },
    render(h) {
      return h(SamlMembershipRoleSelector);
    },
  });
};
