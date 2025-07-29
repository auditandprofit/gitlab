import GridstackDashboard from 'storybook_helpers/dashboards/gridstack_dashboard.vue';
import GridstackPanel from 'storybook_helpers/dashboards/gridstack_panel.vue';
import AreaChart from './area_chart.vue';

export default {
  component: AreaChart,
  title: 'ee/analytics/analytics_dashboards/components/visualizations/area_chart',
};

const Template = (args, { argTypes }) => ({
  components: { AreaChart, GridstackDashboard, GridstackPanel },
  props: Object.keys(argTypes),
  template: `
  <div class="gl-h-48">
    <area-chart :data="data" :options="options" />
  </div>`,
});

const WithGridstack = (args, { argTypes }) => ({
  components: { AreaChart, GridstackDashboard, GridstackPanel },
  props: Object.keys(argTypes),
  template: `
      <gridstack-dashboard :panels="panelsConfig">
        <area-chart :data="data" :options="options" />
      </gridstack-dashboard>`,
});

const areaChartData = [
  ['2024-09-20', 1],
  ['2024-09-21', 3],
  ['2024-09-22', null],
  ['2024-09-23', 1],
  ['2024-09-24', 2],
  ['2024-09-25', null],
  ['2024-09-26', null],
  ['2024-09-27', 3],
  ['2024-09-28', 3],
  ['2024-09-29', 1],
  ['2024-09-30', null],
];

const defaultArgs = {
  data: [
    {
      data: areaChartData,
      name: 'Deployment frequency',
    },
  ],
  options: {
    decimalPlaces: 1,
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
