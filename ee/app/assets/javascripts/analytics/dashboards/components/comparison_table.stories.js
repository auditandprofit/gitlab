import GridstackDashboard from 'storybook_helpers/dashboards/gridstack_dashboard.vue';
import GridstackPanel from 'storybook_helpers/dashboards/gridstack_panel.vue';
import ComparisonTable from './comparison_table.vue';
import { comparisonTableData } from './stories_constants';

export default {
  component: ComparisonTable,
  title: 'ee/analytics/dashboards/components/comparison_table',
};

const Template = (args, { argTypes }) => ({
  components: { ComparisonTable, GridstackDashboard, GridstackPanel },
  props: Object.keys(argTypes),
  template: `<comparison-table v-bind="$props" />`,
});

const WithGridstack = (args, { argTypes }) => ({
  components: { ComparisonTable, GridstackDashboard, GridstackPanel },
  props: Object.keys(argTypes),
  template: `
      <gridstack-dashboard :panels="panelsConfig">
        <comparison-table v-bind="$props" />
      </gridstack-dashboard>`,
});

const defaultArgs = {
  requestPath: 'fake/path/to/entity',
  isProject: true,
  now: new Date('1815-12-10T23:40:00'),
  tableData: comparisonTableData,
  filterLabels: [],
};

export const Default = Template.bind({});
Default.args = defaultArgs;

export const InDashboardPanel = WithGridstack.bind({});
InDashboardPanel.args = {
  ...defaultArgs,
  panelsConfig: [
    {
      id: '1',
      title: 'Comparison table #1',
      gridAttributes: {
        yPos: 0,
        xPos: 0,
        width: 12,
        height: 3,
      },
    },
  ],
};
