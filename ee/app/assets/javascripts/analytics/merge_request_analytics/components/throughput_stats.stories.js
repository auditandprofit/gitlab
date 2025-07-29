import ThroughputStats from './throughput_stats.vue';
import { stats, noDataStats } from './stories_constants';

export default {
  component: ThroughputStats,
  title: 'ee/analytics/merge_request_analytics/components/throughput_stats',
};

const Template = (args, { argTypes }) => ({
  components: { ThroughputStats },
  props: Object.keys(argTypes),
  template: '<throughput-stats v-bind="$props" />',
});

export const Default = Template.bind({});
Default.args = {
  stats,
  isLoading: false,
};

export const NoData = Template.bind({});
NoData.args = { stats: noDataStats };

export const Loading = Template.bind({});
Loading.args = { stats, isLoading: true };
