import { getDayDifference, localeDateFormat, newDate } from '~/lib/utils/datetime_utility';
import { __, sprintf } from '~/locale';
import {
  BUCKETING_INTERVAL_ALL,
  BUCKETING_INTERVAL_MONTHLY,
  BUCKETING_INTERVAL_DAILY,
} from '~/analytics/shared/graphql/constants';
import DoraMetricsQuery from '~/analytics/shared/graphql/dora_metrics.query.graphql';
import { extractQueryResponseFromNamespace, scaledValueForDisplay } from '~/analytics/shared/utils';
import {
  VALUE_STREAM_METRIC_TILE_METADATA,
  DORA_METRICS_NULL_SERIES_TITLE,
  DORA_METRICS_SECONDARY_SERIES_NAME,
  DORA_METRICS,
} from '~/analytics/shared/constants';
import { TABLE_METRICS } from 'ee/analytics/dashboards/constants';
import { DORA_METRICS_CHARTS_ADDITIONAL_OPTS } from 'ee/analytics/analytics_dashboards/constants';
import {
  DATE_RANGE_OPTION_LAST_180_DAYS,
  DATE_RANGE_OPTION_KEYS,
  DATE_RANGE_OPTIONS,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';
import { buildNullSeries } from 'ee/analytics/shared/utils';
import { getStartDate } from 'ee/analytics/analytics_dashboards/components/filters/utils';
import {
  startOfTomorrow,
  lineChartAdditionalSeriesOptions,
} from 'ee/analytics/dora/components/static_data/shared';
import { seriesToMedianSeries, seriesToAverageSeries } from 'ee/analytics/dora/components/util';
import { DEFAULT_NULL_SERIES_OPTIONS, NULL_SERIES_ID } from 'ee/analytics/shared/constants';
import { defaultClient } from '../graphql/client';

const asValue = ({ metrics, targetMetric, units }) => {
  if (!metrics.length) return '-';

  const metricValue = metrics[0][targetMetric] || 0;
  return scaledValueForDisplay(metricValue, units);
};

const calculateAdditionalSeries = ({ targetMetric, rawData, daysCount }) => {
  const seriesName = DORA_METRICS_SECONDARY_SERIES_NAME[targetMetric];
  const formatSeries =
    targetMetric === DORA_METRICS.DEPLOYMENT_FREQUENCY
      ? seriesToAverageSeries
      : seriesToMedianSeries;

  return {
    ...lineChartAdditionalSeriesOptions,
    ...formatSeries(rawData, sprintf(seriesName, { days: daysCount })),
  };
};

const asTimeSeries = ({ metrics, targetMetric, daysCount, nullSeriesTitle = __('No data') }) => {
  // Extracts a date + value, returns an array of arrays [[date, value],[date, value]]
  // Calculates a "null" series and returns all the series in the correct order for rendering
  const rawData = metrics.map(({ date, ...rest }) => {
    const formattedDate = newDate(date);
    return [formattedDate, rest[targetMetric]];
  });

  if (!rawData.some(([, value]) => Boolean(value))) return [];

  const data = { name: VALUE_STREAM_METRIC_TILE_METADATA[targetMetric].label, data: rawData };
  const [nullSeries, primarySeries] = buildNullSeries({
    seriesData: [data],
    nullSeriesTitle,
    nullSeriesOptions: { ...DEFAULT_NULL_SERIES_OPTIONS, id: NULL_SERIES_ID },
  });
  const additionalSeries = calculateAdditionalSeries({ targetMetric, rawData, daysCount });

  return [primarySeries, additionalSeries, nullSeries].map(
    ({ data: seriesData, ...seriesRest }) => ({
      data: seriesData.filter(([, n]) => !Number.isNaN(n)),
      ...seriesRest,
    }),
  );
};

const fetchDoraMetricsQuery = async ({ metric, namespace, startDate, endDate, interval }) => {
  const result = await defaultClient.query({
    query: DoraMetricsQuery,
    variables: {
      fullPath: namespace,
      interval,
      startDate,
      endDate,
    },
  });

  const { metrics } = extractQueryResponseFromNamespace({ result, resultKey: 'dora' });
  const { units } = TABLE_METRICS[metric];
  const daysCount = getDayDifference(startDate, endDate);

  if ([BUCKETING_INTERVAL_DAILY, BUCKETING_INTERVAL_MONTHLY].includes(interval)) {
    return asTimeSeries({
      metrics,
      targetMetric: metric,
      nullSeriesTitle: DORA_METRICS_NULL_SERIES_TITLE[metric] ?? null,
      daysCount,
    });
  }

  return asValue({ metrics, targetMetric: metric, units });
};

export default async function fetch({
  namespace,
  query: {
    metric,
    dateRange: defaultDateRange = DATE_RANGE_OPTION_LAST_180_DAYS,
    interval = BUCKETING_INTERVAL_ALL,
  },
  queryOverrides: { dateRange: dateRangeOverride = null, ...overridesRest } = {},
  filters: {
    dateRangeOption,
    startDate: filtersStartDate = null,
    endDate: filtersEndDate = null,
  } = {},
  setVisualizationOverrides = () => {},
}) {
  let dateRangeKey = dateRangeOption || dateRangeOverride || defaultDateRange;
  if (!DATE_RANGE_OPTION_KEYS.includes(dateRangeKey)) {
    // Default to 180 days if an invalid date range is given
    dateRangeKey = DATE_RANGE_OPTION_LAST_180_DAYS;
  }

  const startDate = getStartDate(dateRangeKey);

  if (interval === BUCKETING_INTERVAL_ALL) {
    const title = DATE_RANGE_OPTIONS[dateRangeKey].text;
    const visualizationOptionOverrides = {
      ...(title && {
        titleIcon: 'clock',
        title,
      }),
    };

    setVisualizationOverrides({ visualizationOptionOverrides });
  } else {
    setVisualizationOverrides({
      visualizationOptionOverrides: {
        ...DORA_METRICS_CHARTS_ADDITIONAL_OPTS[metric],
        chartTooltip: { titleFormatter: localeDateFormat.asDate.format },
      },
    });
  }

  return fetchDoraMetricsQuery({
    startDate: filtersStartDate ?? startDate,
    endDate: filtersEndDate ?? startOfTomorrow,
    metric,
    namespace,
    interval,
    ...overridesRest,
  });
}
