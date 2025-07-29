import { queryThroughputData } from 'ee/analytics/merge_request_analytics/api';
import {
  computeMttmData,
  filterToMRThroughputQueryObject,
} from 'ee/analytics/merge_request_analytics/utils';
import { startOfTomorrow } from 'ee/analytics/dora/components/static_data/shared';
import { getStartDate } from 'ee/analytics/analytics_dashboards/components/filters/utils';
import { DATE_RANGE_OPTION_LAST_365_DAYS } from 'ee/analytics/analytics_dashboards/components/filters/constants';

export default async function fetch({
  namespace,
  query: { dateRange: defaultDateRange = DATE_RANGE_OPTION_LAST_365_DAYS } = {},
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

  const { value = 0 } = computeMttmData(rawData);
  return value;
}
