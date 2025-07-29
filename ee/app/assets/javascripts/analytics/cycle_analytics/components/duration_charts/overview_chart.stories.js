import OverviewChart from './overview_chart.vue';
import { overviewChartData } from './stories_constants';

export default {
  component: OverviewChart,
  title: 'ee/analytics/cycle_analytics/components/overview_chart',
};

const Template = (args, { argTypes }) => ({
  components: { OverviewChart },
  props: Object.keys(argTypes),
  template: '<overview-chart v-bind="$props" />',
});

export const Default = Template.bind({});
Default.args = {
  isLoading: false,
  plottableData: overviewChartData,
};

export const Loading = Template.bind({});
Loading.args = {
  isLoading: true,
  plottableData: [],
};

export const NoData = Template.bind({});
NoData.args = {
  isLoading: false,
  plottableData: [],
};

export const ErrorMessage = Template.bind({});
ErrorMessage.args = {
  isLoading: false,
  plottableData: [],
  errorMessage: 'Failed to load chart',
};
