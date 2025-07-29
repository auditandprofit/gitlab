import Vue from 'vue';
import { GlToast } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import { parseBoolean } from '~/lib/utils/common_utils';
import createDefaultClient from '~/lib/graphql';
import AdminRunnersDashboardApp from './admin_runners_dashboard_app.vue';

Vue.use(VueApollo);
Vue.use(GlToast);

export const initAdminRunnersDashboard = (selector = '#js-admin-runners-dashboard') => {
  const el = document.querySelector(selector);

  const { adminRunnersPath, newRunnerPath, clickhouseCiAnalyticsAvailable, canAdminRunners } =
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
      return h(AdminRunnersDashboardApp, {
        props: {
          adminRunnersPath,
          newRunnerPath,
          canAdminRunners: parseBoolean(canAdminRunners),
        },
      });
    },
  });
};
