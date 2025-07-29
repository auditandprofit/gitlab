import DataTable from './data_table.vue';
import ChangePercentageIndicator from './change_percentage_indicator.vue';

export default {
  component: ChangePercentageIndicator,
  title:
    'ee/analytics/analytics_dashboards/components/visualizations/data_table/change_percentage_indicator',
};

const Template = (args, { argTypes }) => ({
  components: { ChangePercentageIndicator },
  props: Object.keys(argTypes),
  template: `<change-percentage-indicator :value="value" :tooltip="tooltip" :invert-trend-color="invertTrendColor" />`,
});

const TableTemplate = (args, { argTypes }) => ({
  components: { DataTable },
  props: Object.keys(argTypes),
  template: `<data-table :data="data" :options="options" />`,
});

const tooltip = 'Tooltip label is cool';

export const Default = Template.bind({});
Default.args = { value: 0.25, tooltip, invertTrendColor: false };

export const WithInvertTrendColor = Template.bind({});
WithInvertTrendColor.args = { value: 0.25, tooltip, invertTrendColor: true };

export const NegativeChange = Template.bind({});
NegativeChange.args = { value: -0.125, tooltip, invertTrendColor: false };

export const NoChange = Template.bind({});
NoChange.args = { tooltip, invertTrendColor: false, value: 0 };

export const InTable = TableTemplate.bind({});
InTable.args = {
  data: { nodes: [{ change: { value: 0.15, tooltip }, metric: 'Vulnerabilities' }] },
  options: {
    fields: [
      { key: 'metric', label: 'Title' },
      { key: 'change', label: 'Change', component: 'ChangePercentageIndicator' },
    ],
  },
};
