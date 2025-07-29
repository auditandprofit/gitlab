import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';
import RoleDetails from './components/role_details/role_details.vue';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export const initRoleDetailsApp = () => {
  const el = document.querySelector('#js-role-details');

  if (!el) {
    return null;
  }

  return new Vue({
    el,
    name: 'RoleDetailsRoot',
    apolloProvider,
    render(createElement) {
      return createElement(RoleDetails, {
        props: {
          roleId: el.dataset.id,
          listPagePath: el.dataset.listPagePath,
          isAdminRole: parseBoolean(el.dataset.isAdminRole),
        },
      });
    },
  });
};
