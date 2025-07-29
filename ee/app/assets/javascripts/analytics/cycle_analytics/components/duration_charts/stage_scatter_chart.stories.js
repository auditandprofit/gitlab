import { TYPENAME_ISSUE } from '~/graphql_shared/constants';
import StageScatterChart from './stage_scatter_chart.vue';
import { stageScatterChartData } from './stories_constants';

export default {
  component: StageScatterChart,
  title: 'ee/analytics/cycle_analytics/components/stage_scatter_chart',
};

const stageTitle = 'VSA stage';
const startDate = new Date('2023-09-06');
const endDate = new Date('2023-10-05');

const Template = (args, { argTypes }) => ({
  components: { StageScatterChart },
  props: Object.keys(argTypes),
  template: '<stage-scatter-chart v-bind="$props" />',
});

export const Default = Template.bind({});
Default.args = {
  stageTitle,
  issuableType: TYPENAME_ISSUE,
  plottableData: stageScatterChartData,
  startDate,
  endDate,
};

export const Loading = Template.bind({});
Loading.args = {
  stageTitle,
  isLoading: true,
  startDate,
  endDate,
};

export const NoData = Template.bind({});
NoData.args = {
  ...Default.args,
  plottableData: [],
};

export const ErrorMessage = Template.bind({});
ErrorMessage.args = {
  ...Default.args,
  errorMessage: 'Failed to load chart',
};
