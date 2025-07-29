import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { convertObjectPropsToCamelCase, parseBoolean } from '~/lib/utils/common_utils';
import App from './pages/app.vue';

Vue.use(VueApollo);

const createApolloProvider = () => {
  const defaultClient = createDefaultClient();

  return new VueApollo({ defaultClient });
};

const initWorkspacesSettingsApp = () => {
  const el = document.querySelector('#js-workspaces-settings');

  if (!el) {
    return null;
  }

  const { namespace, canAdminClusterAgentMapping } = convertObjectPropsToCamelCase(el.dataset);

  return new Vue({
    el,
    name: 'WorkspacesSettingsRoot',
    apolloProvider: createApolloProvider(),
    provide: {
      namespace,
      canAdminClusterAgentMapping: parseBoolean(canAdminClusterAgentMapping),
    },
    render: (createElement) => createElement(App),
  });
};

export { initWorkspacesSettingsApp };
