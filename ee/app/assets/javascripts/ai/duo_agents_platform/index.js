import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { injectVueAppBreadcrumbs } from '~/lib/utils/breadcrumbs';
import DuoAgentsPlatformBreadcrumbs from './router/duo_agents_platform_breadcrumbs.vue';
import { activeNavigationWatcher } from './router/utils';

import DuoAgentsPlatformApp from './duo_agents_platform_app.vue';
import { createRouter } from './router';

export const initDuoAgentsPlatformPage = (selector = '#js-duo-agents-platform-page') => {
  const el = document.querySelector(selector);
  if (!el) {
    return null;
  }

  const { dataset } = el;
  const {
    agentsPlatformBaseRoute,
    duoAgentsInvokePath,
    projectId,
    projectPath,
    emptyStateIllustrationPath,
  } = dataset;
  const router = createRouter(agentsPlatformBaseRoute);
  router.beforeEach(activeNavigationWatcher);

  Vue.use(VueApollo);

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  injectVueAppBreadcrumbs(router, DuoAgentsPlatformBreadcrumbs);

  return new Vue({
    el,
    name: 'DuoAgentsPlatformApp',
    router,
    apolloProvider,
    provide: {
      duoAgentsInvokePath,
      emptyStateIllustrationPath,
      projectPath,
      projectId,
    },
    render(h) {
      return h(DuoAgentsPlatformApp);
    },
  });
};
