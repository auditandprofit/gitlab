import getMergeRequests from 'ee/analytics/merge_request_analytics/graphql/queries/throughput_table.query.graphql';
import { INITIAL_PAGINATION_STATE } from 'ee/analytics/merge_request_analytics/constants';
import { extractQueryResponseFromNamespace } from '~/analytics/shared/utils';
import { startOfTomorrow } from 'ee/analytics/dora/components/static_data/shared';
import { getStartDate } from 'ee/analytics/analytics_dashboards/components/filters/utils';
import { DATE_RANGE_OPTION_LAST_365_DAYS } from 'ee/analytics/analytics_dashboards/components/filters/constants';
import { filterToMRThroughputQueryObject } from 'ee/analytics/merge_request_analytics/utils';
import { defaultClient } from '../graphql/client';

const QUERY_RESULT_KEY = 'mergeRequests';

const fetchMergeRequests = async ({
  namespace,
  startDate,
  endDate,
  labels = null,
  notLabels = null,
  sourceBranches = null,
  targetBranches = null,
  pagination = INITIAL_PAGINATION_STATE,
  // The rest should not be set to null
  milestoneTitle,
  notMilestoneTitle,
  assigneeUsername,
  authorUsername,
}) =>
  defaultClient
    .query({
      query: getMergeRequests,
      variables: {
        fullPath: namespace,
        startDate,
        endDate,
        labels,
        notLabels,
        sourceBranches,
        targetBranches,
        milestoneTitle,
        notMilestoneTitle,
        assigneeUsername,
        authorUsername,
        ...pagination,
      },
    })
    .then((result) => {
      const { nodes, pageInfo } = extractQueryResponseFromNamespace({
        result,
        resultKey: QUERY_RESULT_KEY,
      });

      if (!nodes?.length) {
        return null;
      }

      return {
        list: nodes || [],
        pageInfo: {
          ...pagination,
          ...pageInfo,
        },
      };
    });

export default function fetch({
  namespace,
  query: { dateRange = DATE_RANGE_OPTION_LAST_365_DAYS },
  queryOverrides = {},
  filters: { startDate: filtersStartDate, endDate = startOfTomorrow, searchFilters } = {},
}) {
  const startDate = filtersStartDate || getStartDate(dateRange);

  return fetchMergeRequests({
    namespace,
    startDate,
    endDate,
    ...filterToMRThroughputQueryObject(searchFilters),
    ...queryOverrides,
  });
}
