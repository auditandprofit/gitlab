import { GlToast } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { WORKSPACE_GROUP, WORKSPACE_PROJECT } from '~/issues/constants';
import createDefaultClient from '~/lib/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';
import { injectVueAppBreadcrumbs } from '~/lib/utils/breadcrumbs';
import App from './components/app.vue';
import IterationBreadcrumb from './components/iteration_breadcrumb.vue';
import createRouter from './router';

Vue.use(GlToast);
Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(
    {},
    {
      batchMax: 1,
    },
  ),
});

export function initCadenceApp({ namespaceType }) {
  const el = document.querySelector('.js-iteration-cadence-app');

  if (!el) {
    return null;
  }

  const {
    fullPath,
    cadencesListPath,
    canCreateCadence,
    canEditCadence,
    canCreateIteration,
    canEditIteration,
    hasScopedLabelsFeature,
    labelsFetchPath,
    previewMarkdownPath,
    noIssuesSvgPath,
    instanceTimezone,
  } = el.dataset;
  const router = createRouter({
    base: cadencesListPath,
    permissions: {
      canCreateCadence: parseBoolean(canCreateCadence),
      canEditCadence: parseBoolean(canEditCadence),
      canCreateIteration: parseBoolean(canCreateIteration),
      canEditIteration: parseBoolean(canEditIteration),
    },
  });

  injectVueAppBreadcrumbs(router, IterationBreadcrumb, apolloProvider);

  return new Vue({
    el,
    name: 'IterationsRoot',
    router,
    apolloProvider,
    provide: {
      fullPath,
      cadencesListPath,
      canCreateCadence: parseBoolean(canCreateCadence),
      canEditCadence: parseBoolean(canEditCadence),
      namespaceType,
      canCreateIteration: parseBoolean(canCreateIteration),
      canEditIteration: parseBoolean(canEditIteration),
      hasScopedLabelsFeature: parseBoolean(hasScopedLabelsFeature),
      labelsFetchPath,
      previewMarkdownPath,
      noIssuesSvgPath,
      instanceTimezone: JSON.parse(instanceTimezone || '{}'),
    },
    render(createElement) {
      return createElement(App);
    },
  });
}

export const initGroupCadenceApp = () => initCadenceApp({ namespaceType: WORKSPACE_GROUP });
export const initProjectCadenceApp = () => initCadenceApp({ namespaceType: WORKSPACE_PROJECT });
