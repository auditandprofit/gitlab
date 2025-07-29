import createMockApollo from 'helpers/mock_apollo_helper';
import { withVuexStore } from 'storybook_addons/vuex_store';
import ThroughputTableProvider from 'ee/analytics/merge_request_analytics/components/throughput_table_provider.vue';
import filters from '~/vue_shared/components/filtered_search_bar/store/modules/filters';
import throughputTableQuery from '../graphql/queries/throughput_table.query.graphql';
import {
  throughputTableData,
  throughputTableNoData,
  startDate,
  endDate,
  fullPath,
} from './stories_constants';

const defaultQueryResolver = { data: throughputTableData };

export default {
  component: ThroughputTableProvider,
  title: 'ee/analytics/merge_request_analytics/components/throughput_table_provider',
  decorators: [withVuexStore],
};

const createStory = ({ mockApollo, requestHandler = defaultQueryResolver } = {}) => {
  const defaultApolloProvider = createMockApollo([
    [throughputTableQuery, () => Promise.resolve(requestHandler)],
  ]);

  return (args, { argTypes, createVuexStore }) => ({
    components: { ThroughputTableProvider },
    apolloProvider: mockApollo || defaultApolloProvider,
    store: createVuexStore({
      modules: { filters },
    }),
    provide: {
      fullPath,
    },
    props: Object.keys(argTypes),
    template: '<throughput-table-provider v-bind="$props"/>',
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
  render: createStory({ requestHandler: { data: throughputTableNoData } }),
  args: Default.args,
};

export const Loading = {
  render: createStory({
    mockApollo: createMockApollo([[throughputTableQuery, () => new Promise(() => {})]]),
  }),
  args: Default.args,
};
