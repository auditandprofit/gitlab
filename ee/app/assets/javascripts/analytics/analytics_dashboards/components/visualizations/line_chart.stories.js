import GridstackDashboard from 'storybook_helpers/dashboards/gridstack_dashboard.vue';
import GridstackPanel from 'storybook_helpers/dashboards/gridstack_panel.vue';
import { UNITS } from '~/analytics/shared/constants';
import LineChart from './line_chart.vue';

export default {
  component: LineChart,
  title: 'ee/analytics/analytics_dashboards/components/visualizations/line_chart',
};

const Template = (args, { argTypes }) => ({
  components: { LineChart, GridstackDashboard, GridstackPanel },
  props: Object.keys(argTypes),
  template: `
  <div class="gl-h-48">
    <line-chart :data="data" :options="options" />
  </div>`,
});

const WithGridstack = (args, { argTypes }) => ({
  components: { LineChart, GridstackDashboard, GridstackPanel },
  props: Object.keys(argTypes),
  template: `
      <gridstack-dashboard :panels="panelsConfig">
        <line-chart :data="data" :options="options" />
      </gridstack-dashboard>`,
});

const LineChartData = [
  ['Mon', 1184],
  ['Tue', 1346],
  ['Wed', 1035],
  ['Thu', 1226],
  ['Fri', 1421],
  ['Sat', 1347],
  ['Sun', 1035],
];

const defaultArgs = {
  data: [
    {
      data: LineChartData,
      name: 'Deployment frequency',
    },
  ],
  options: {
    xAxis: { type: 'category' },
    yAxis: { type: 'value' },
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

export const WithHumanizedTooltipValues = Template.bind({});
WithHumanizedTooltipValues.args = {
  data: defaultArgs.data,
  options: {
    ...defaultArgs.options,
    chartTooltip: {
      valueUnit: UNITS.PER_DAY,
    },
  },
};
