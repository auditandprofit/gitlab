import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import createRouter from './router';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

function mountSelfHostedDuoRootApp() {
  const el = document.getElementById('js-duo-self-hosted');

  if (!el) {
    return null;
  }

  const { basePath, modelOptions, betaModelsEnabled, duoConfigurationSettingsPath } = JSON.parse(
    el.dataset.viewModel,
  );

  const router = createRouter(basePath);

  return new Vue({
    el,
    name: 'SelfHostedDuoRootApp',
    apolloProvider,
    router,
    provide: {
      basePath,
      modelOptions,
      betaModelsEnabled,
      duoConfigurationSettingsPath,
    },
    render(createElement) {
      return createElement('router-view');
    },
  });
}

mountSelfHostedDuoRootApp();
