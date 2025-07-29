import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlToast } from '@gitlab/ui';

import createDefaultClient from '~/lib/graphql';

import AiCatalogApp from './ai_catalog_app.vue';
import { createRouter } from './router';

export const initAiCatalog = (selector = '#js-ai-catalog') => {
  const el = document.querySelector(selector);

  if (!el) {
    return null;
  }

  const { dataset } = el;
  const { aiCatalogIndexPath } = dataset;

  Vue.use(VueApollo);
  Vue.use(GlToast);

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  return new Vue({
    el,
    name: 'AiCatalogRoot',
    router: createRouter(aiCatalogIndexPath),
    apolloProvider,
    render(h) {
      return h(AiCatalogApp);
    },
  });
};
