import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import PipelineSubscriptionsApp from './pipeline_subscriptions_app.vue';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export default () => {
  const el = document.getElementById('js-pipeline-subscriptions-app');

  if (!el) {
    return null;
  }

  const { projectPath } = el.dataset;

  return new Vue({
    el,
    name: 'PipelineSubscriptionsRoot',
    apolloProvider,
    provide: {
      projectPath,
    },
    render(createElement) {
      return createElement(PipelineSubscriptionsApp);
    },
  });
};
