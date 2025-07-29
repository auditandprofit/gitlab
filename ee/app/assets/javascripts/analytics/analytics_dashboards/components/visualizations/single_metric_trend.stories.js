import GridstackDashboard from 'storybook_helpers/dashboards/gridstack_dashboard.vue';
import GridstackPanel from 'storybook_helpers/dashboards/gridstack_panel.vue';
import SingleMetricTrend from './single_metric_trend.vue';

export default {
  component: SingleMetricTrend,
  title: 'ee/analytics/analytics_dashboards/components/visualizations/metric_trend',
};

const Template = (args, { argTypes }) => ({
  components: { SingleMetricTrend, GridstackDashboard, GridstackPanel },
  props: Object.keys(argTypes),
  template: `<single-metric-trend :data="data" :options="options" />`,
});

const WithGridstack = (args, { argTypes }) => ({
  components: { SingleMetricTrend, GridstackDashboard, GridstackPanel },
  props: Object.keys(argTypes),
  template: `
      <gridstack-dashboard :panels="panelsConfig">
        <single-metric-trend :data="data" :options="options" />
      </gridstack-dashboard>`,
});

const defaultArgs = {
  data: {
    value: 35.16,
    trend: [
      ['Mon', 10],
      ['Tue', 15],
      ['Wed', 9],
      ['Thu', 22],
      ['Fri', 29],
      ['Sat', 20],
      ['Sun', 18],
    ],
  },
  options: {
    decimalPlaces: 1,
  },
};

export const Default = Template.bind({});
Default.args = defaultArgs;

export const FlatTrend = Template.bind({});
FlatTrend.args = {
  ...defaultArgs,
  data: {
    value: 0,
    trend: [
      ['Mon', 0],
      ['Tue', 0],
      ['Wed', 0],
      ['Thu', 0],
      ['Fri', 0],
      ['Sat', 0],
      ['Sun', 0],
    ],
  },
};

export const NoTrend = Template.bind({});
NoTrend.args = {
  ...defaultArgs,
  data: {
    value: 0,
    trend: [
      ['Mon', null],
      ['Tue', null],
      ['Wed', null],
      ['Thu', null],
      ['Fri', null],
      ['Sat', null],
      ['Sun', null],
    ],
  },
};

export const InDashboardPanel = WithGridstack.bind({});
InDashboardPanel.args = {
  ...defaultArgs,
  panelsConfig: [
    {
      id: '1',
      title: 'Metric trend #1',
      gridAttributes: {
        yPos: 0,
        xPos: 0,
        width: 3,
        height: 2,
      },
    },
  ],
};
