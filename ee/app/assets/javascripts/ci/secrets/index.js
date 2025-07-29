import { GlToast } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { injectVueAppBreadcrumbs } from '~/lib/utils/breadcrumbs';
import createRouter from './router';
import SecretsApp from './components/secrets_app.vue';
import SecretsBreadcrumbs from './components/secrets_breadcrumbs.vue';
import { ENTITY_GROUP, ENTITY_PROJECT } from './constants';

Vue.use(VueApollo);
Vue.use(GlToast);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

// eslint-disable-next-line max-params
const initSecretsApp = (el, app, props, basePath) => {
  const router = createRouter(basePath, props);

  if (window.location.href.includes(basePath)) {
    injectVueAppBreadcrumbs(router, SecretsBreadcrumbs);
  }

  return new Vue({
    el,
    router,
    name: 'SecretsRoot',
    apolloProvider,
    render(createElement) {
      return createElement(app, { props });
    },
  });
};

export const initGroupSecretsApp = () => {
  const el = document.querySelector('#js-group-secrets-manager');

  if (!el) {
    return false;
  }

  const { groupPath, basePath } = el.dataset;

  return initSecretsApp(el, SecretsApp, { entity: ENTITY_GROUP, fullPath: groupPath }, basePath);
};

export const initProjectSecretsApp = () => {
  const el = document.querySelector('#js-project-secrets-manager');

  if (!el) {
    return false;
  }

  const { projectPath, basePath } = el.dataset;

  return initSecretsApp(
    el,
    SecretsApp,
    { entity: ENTITY_PROJECT, fullPath: projectPath },
    basePath,
  );
};
