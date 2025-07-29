import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import ModelSelectionApp from 'ee/ai/model_selection/app.vue';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

function mountModelSelectionApp() {
  const el = document.getElementById('js-gitlab-duo-model-selection');

  if (!el) {
    return null;
  }

  const { groupId } = JSON.parse(el.dataset.viewModel);

  return new Vue({
    el,
    name: 'ModelSelectionApp',
    apolloProvider,
    provide: {
      groupId,
    },
    render(createElement) {
      return createElement(ModelSelectionApp);
    },
  });
}

mountModelSelectionApp();
