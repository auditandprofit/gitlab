import Vue from 'vue';
import { GlToast } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import { parseBoolean } from '~/lib/utils/common_utils';
import createDefaultClient from '~/lib/graphql';
import GroupRunnersDashboardApp from './group_runners_dashboard_app.vue';

Vue.use(VueApollo);
Vue.use(GlToast);

export const initGroupRunnersDashboard = (selector = '#js-group-runners-dashboard') => {
  const el = document.querySelector(selector);

  const { groupFullPath, groupRunnersPath, newRunnerPath, clickhouseCiAnalyticsAvailable } =
    el.dataset;

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  return new Vue({
    el,
    apolloProvider,
    provide: {
      clickhouseCiAnalyticsAvailable: parseBoolean(clickhouseCiAnalyticsAvailable),
    },
    render(h) {
      return h(GroupRunnersDashboardApp, {
        props: {
          groupFullPath,
          groupRunnersPath,
          newRunnerPath,
        },
      });
    },
  });
};
