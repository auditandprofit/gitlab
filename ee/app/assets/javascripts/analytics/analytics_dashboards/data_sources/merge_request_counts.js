import { queryThroughputData } from 'ee/analytics/merge_request_analytics/api';
import {
  filterToMRThroughputQueryObject,
  formatThroughputChartData,
} from 'ee/analytics/merge_request_analytics/utils';
import { startOfTomorrow } from 'ee/analytics/dora/components/static_data/shared';
import { getStartDate } from 'ee/analytics/analytics_dashboards/components/filters/utils';
import { DATE_RANGE_OPTION_LAST_365_DAYS } from 'ee/analytics/analytics_dashboards/components/filters/constants';

const responseHasAnyData = (rawData) => Object.values(rawData).some(({ count }) => count);

export default async function fetch({
  namespace,
  query: { dateRange: defaultDateRange = DATE_RANGE_OPTION_LAST_365_DAYS },
  queryOverrides = {},
  filters: { startDate: filtersStartDate, endDate = startOfTomorrow, searchFilters } = {},
}) {
  const startDate = filtersStartDate || getStartDate(defaultDateRange);

  const rawData = await queryThroughputData({
    namespace,
    startDate,
    endDate,
    ...filterToMRThroughputQueryObject(searchFilters),
    ...queryOverrides,
  });

  if (!responseHasAnyData(rawData)) {
    // return an empty object so the correct dashboard "empty state" is rendered
    return {};
  }

  return formatThroughputChartData(rawData);
}
