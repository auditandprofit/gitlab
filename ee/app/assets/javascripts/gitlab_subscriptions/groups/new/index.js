import Vue from 'vue';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import App from './components/subscription_group_selector.vue';

export default () => {
  const el = document.getElementById('js-new-gitlab-subscription-group');

  if (!el) return null;

  const { rootUrl } = el.dataset;
  const plansData = convertObjectPropsToCamelCase(JSON.parse(el.dataset.plansData), { deep: true });
  const eligibleGroups = convertObjectPropsToCamelCase(JSON.parse(el.dataset.eligibleGroups), {
    deep: true,
  });

  return new Vue({
    el,
    components: {
      App,
    },
    render(createElement) {
      return createElement(App, {
        props: {
          rootUrl,
          plansData,
          eligibleGroups,
        },
      });
    },
  });
};
