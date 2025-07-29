import DataTable from './data_table.vue';
import TrendLine from './trend_line.vue';

export default {
  component: TrendLine,
  title: 'ee/analytics/analytics_dashboards/components/visualizations/data_table/trend_line',
};

const Template = (args, { argTypes }) => ({
  components: { TrendLine },
  props: Object.keys(argTypes),
  template: `<trend-line :data="data" :tooltip-label="tooltipLabel" :invert-trend-color="invertTrendColor" />`,
});

const TableTemplate = (args, { argTypes }) => ({
  components: { DataTable },
  props: Object.keys(argTypes),
  template: `<data-table :data="data" :options="options" />`,
});

const data = [
  ['Jan', 20],
  ['Feb', 5],
  ['Mar', 4],
  ['Apr', 11],
  ['May', 13],
  ['Jun', 21],
];

const tooltipLabel = 'Tooltip label is cool';

export const Default = Template.bind({});
Default.args = { data, tooltipLabel, invertTrendColor: false };

export const WithInvertTrendColor = Template.bind({});
WithInvertTrendColor.args = { data, tooltipLabel, invertTrendColor: true };

export const IsLoading = Template.bind({});
IsLoading.args = { tooltipLabel, invertTrendColor: false, data: [] };

export const InTable = TableTemplate.bind({});
InTable.args = {
  data: {
    nodes: [{ trend: { data, tooltipLabel, invertTrendColor: false }, metric: 'Vulnerabilities' }],
  },
  options: {
    fields: [
      { key: 'metric', label: 'Title' },
      { key: 'trend', label: 'Trend', component: 'TrendLine' },
    ],
  },
};
