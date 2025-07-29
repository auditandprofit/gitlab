import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import MergeTrainsApp from './merge_trains_app.vue';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export const initMergeTrainsApp = () => {
  const el = document.querySelector('#js-merge-trains');

  if (!el) {
    return false;
  }

  const { fullPath, defaultBranch, projectId, projectName } = el.dataset;

  return new Vue({
    el,
    name: 'MergeTrainsRoot',
    apolloProvider,
    provide: {
      fullPath,
      defaultBranch,
      projectId,
      projectName,
    },
    render(createElement) {
      return createElement(MergeTrainsApp);
    },
  });
};
