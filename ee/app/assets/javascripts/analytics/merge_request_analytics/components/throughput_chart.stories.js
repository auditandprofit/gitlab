import createMockApollo from 'helpers/mock_apollo_helper';
import { withVuexStore } from 'storybook_addons/vuex_store';
import filters from '~/vue_shared/components/filtered_search_bar/store/modules/filters';
import throughputChartQueryBuilder from '../graphql/throughput_chart_query_builder';
import ThroughputChart from './throughput_chart.vue';
import {
  startDate,
  endDate,
  fullPath,
  throughputChartData,
  throughputChartNoData,
} from './stories_constants';

const defaultQueryResolver = { data: { throughputChartData } };
const query = throughputChartQueryBuilder(startDate, endDate);

export default {
  component: ThroughputChart,
  title: 'ee/analytics/merge_request_analytics/components/throughput_chart',
  decorators: [withVuexStore],
};

const createStory = ({ mockApollo, requestHandler = defaultQueryResolver } = {}) => {
  const defaultApolloProvider = createMockApollo([[query, () => Promise.resolve(requestHandler)]]);

  return (args, { argTypes, createVuexStore }) => ({
    components: { ThroughputChart },
    apolloProvider: mockApollo || defaultApolloProvider,
    store: createVuexStore({
      modules: { filters },
    }),
    provide: {
      fullPath,
    },
    props: Object.keys(argTypes),
    template: '<throughput-chart  v-bind="$props"/>',
  });
};

export const Default = {
  render: createStory(),
  args: {
    startDate,
    endDate,
  },
};

export const NoData = {
  render: createStory({
    requestHandler: { data: { throughputChartData: throughputChartNoData } },
  }),
  args: Default.args,
};

export const Loading = {
  render: createStory({
    mockApollo: createMockApollo([[query, () => new Promise(() => {})]]),
  }),
  args: Default.args,
};
