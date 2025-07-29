import $ from 'jquery';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import BurnCharts from './components/burn_charts.vue';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export default () => {
  // generate burndown chart (if data available)
  const container = '.burndown-chart';
  const $chartEl = $(container);

  if ($chartEl.length) {
    const startDate = $chartEl.data('startDate');
    const dueDate = $chartEl.data('dueDate');
    const milestoneId = $chartEl.data('milestoneId');
    const burndownEventsPath = $chartEl.data('burndownEventsPath');
    const isLegacy = $chartEl.data('isLegacy');

    // eslint-disable-next-line no-new
    new Vue({
      el: container,
      components: {
        BurnCharts,
      },
      apolloProvider,
      render(createElement) {
        return createElement('burn-charts', {
          props: {
            showNewOldBurndownToggle: isLegacy,
            burndownEventsPath,
            startDate,
            dueDate,
            milestoneId,
          },
        });
      },
    });
  }
};
