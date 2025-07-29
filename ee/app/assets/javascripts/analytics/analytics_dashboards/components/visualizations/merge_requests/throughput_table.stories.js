import GridstackDashboard from 'storybook_helpers/dashboards/gridstack_dashboard.vue';
import GridstackPanel from 'storybook_helpers/dashboards/gridstack_panel.vue';
import { INITIAL_PAGINATION_STATE } from 'ee/analytics/merge_request_analytics/constants';
import MergeRequestsThroughputTable from './throughput_table.vue';
import { throughputTableData as list } from './stories_constants';

export default {
  component: MergeRequestsThroughputTable,
  title:
    'ee/analytics/analytics_dashboards/components/visualizations/merge_requests/throughput_table',
};

const Template = (args, { argTypes }) => ({
  components: { MergeRequestsThroughputTable },
  props: Object.keys(argTypes),
  template: `
  <div class="gl-h-48">
    <merge-requests-throughput-table :data="data" :options="options" />
  </div>`,
});

const WithGridstack = (args, { argTypes }) => ({
  components: { MergeRequestsThroughputTable, GridstackDashboard, GridstackPanel },
  props: Object.keys(argTypes),
  template: `
      <gridstack-dashboard :panels="panelsConfig">
        <merge-requests-throughput-table :data="data" :options="options" />
      </gridstack-dashboard>`,
});

const defaultArgs = {
  data: {
    list,
    pageInfo: INITIAL_PAGINATION_STATE,
  },
};

export const Default = Template.bind({});
Default.args = defaultArgs;

export const InDashboardPanel = WithGridstack.bind({});
InDashboardPanel.args = {
  ...defaultArgs,
  panelsConfig: [
    {
      id: '1',
      title: 'Panel #1',
      gridAttributes: {
        yPos: 0,
        xPos: 0,
        width: 12,
        height: 3,
      },
    },
  ],
};
