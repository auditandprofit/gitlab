import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';
import RoleEdit from './components/manage_role/role_edit.vue';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export const initEditMemberRoleApp = () => {
  const el = document.querySelector('#js-edit-member-role');

  if (!el) {
    return null;
  }

  const { listPagePath, roleId, isAdminRole } = el.dataset;

  return new Vue({
    el,
    name: 'EditRoleRoot',
    apolloProvider,
    provide: { isAdminRole: parseBoolean(isAdminRole) },
    render(createElement) {
      return createElement(RoleEdit, {
        props: { roleId: Number(roleId), listPagePath },
      });
    },
  });
};
