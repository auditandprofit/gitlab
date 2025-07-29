import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import Translate from '~/vue_shared/translate';
import WorkItemSettings from './work_item_settings.vue';

Vue.use(VueApollo);
Vue.use(Translate);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export function initWorkItemSettingsApp() {
  const el = document.querySelector('#js-work-items-settings-form');
  if (!el) return;

  const { fullPath } = el.dataset;

  // eslint-disable-next-line no-new
  new Vue({
    el,
    apolloProvider,
    render(createElement) {
      return createElement(WorkItemSettings, {
        props: {
          fullPath,
        },
      });
    },
  });
}
