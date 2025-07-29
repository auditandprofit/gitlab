import Vue from 'vue';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import GroupLinkRoleSelector from './components/group_link_role_selector.vue';

export default () => {
  const el = document.querySelector('.js-group-link-role-selector');

  if (!el) {
    return null;
  }

  const {
    groupLinkRoleSelectorData = {},
    baseAccessLevelInputName,
    memberRoleIdInputName,
  } = el.dataset;

  const { standardRoles, customRoles = [] } = convertObjectPropsToCamelCase(
    JSON.parse(groupLinkRoleSelectorData),
    { deep: true },
  );

  return new Vue({
    el,
    name: 'GroupLinkRoleSelectorRoot',
    provide: {
      standardRoles,
      customRoles,
    },
    render(h) {
      return h(GroupLinkRoleSelector, {
        props: {
          baseAccessLevelInputName,
          memberRoleIdInputName,
        },
      });
    },
  });
};
