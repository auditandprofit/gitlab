import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import createRouter from './router';
import BaseApp from './base_app.vue';

Vue.use(VueApollo);

export default () => {
  const el = document.getElementById('js-mount-index-ml-agents');

  if (!el) {
    return false;
  }

  const { basePath, projectPath, userId } = el.dataset;

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  const router = createRouter(basePath);

  return new Vue({
    el,
    name: 'AiAgents',
    apolloProvider,
    router,
    provide: {
      projectPath,
      userId,
    },
    render(h) {
      return h(BaseApp);
    },
  });
};
