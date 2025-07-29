import {
  USAGE_OVERVIEW_DEFAULT_DATE_RANGE,
  USAGE_OVERVIEW_GROUP_ONLY_IDENTIFIERS,
  USAGE_OVERVIEW_METADATA,
  USAGE_OVERVIEW_QUERY_INCLUDE_KEYS,
} from '~/analytics/shared/constants';
import dateFormat, { masks } from '~/lib/dateformat';
import { __, sprintf, s__ } from '~/locale';
import {
  BACKGROUND_AGGREGATION_DOCS_LINK,
  BACKGROUND_AGGREGATION_WARNING_TITLE,
  ENABLE_BACKGROUND_AGGREGATION_WARNING_TEXT,
  GENERIC_DASHBOARD_ERROR,
  UNSUPPORTED_PROJECT_NAMESPACE_ERROR,
} from 'ee/analytics/dashboards/constants';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import getUsageOverviewQuery from 'ee/analytics/analytics_dashboards/graphql/queries/get_usage_overview.query.graphql';
import { toYmd } from '~/analytics/shared/utils';

/**
 * Constructs the query variables that specifies the metric
 * to be included in the response.
 */
export const prepareQuery = (queryKeyToInclude) =>
  Object.entries(USAGE_OVERVIEW_QUERY_INCLUDE_KEYS).reduce((acc, [identifier, key]) => {
    return { ...acc, [key]: queryKeyToInclude === identifier };
  }, {});

const displayMetricValue = ({ value, overviewCountsAggregationEnabled = false }) => {
  if (value > 0) return value;
  return overviewCountsAggregationEnabled ? 0 : '-';
};

const extractUsageMetricData = ({
  metric,
  data,
  overviewCountsAggregationEnabled = false,
} = {}) => {
  const metricData = data?.[metric];

  if (!metricData) return null;

  const {
    options: { title, titleIcon },
  } = USAGE_OVERVIEW_METADATA[metric];

  const value = displayMetricValue({ value: metricData?.count, overviewCountsAggregationEnabled });
  const recordedAt = metricData.recordedAt
    ? dateFormat(metricData.recordedAt, `${masks.isoDate} ${masks.shortTime}`)
    : null;
  const metricUsageText = s__('Analytics|Usage data is a cumulative count and is updated monthly.');
  const lastUpdatedText = s__('Analytics|Last updated: %{recordedAt}');
  const tooltipDescription = `${sprintf(metricUsageText, { metric: title })} ${recordedAt ? sprintf(lastUpdatedText, { recordedAt }) : ''}`;

  return {
    value,
    visualizationOverrides: {
      title,
      titleIcon,
      tooltip: {
        description: tooltipDescription,
      },
    },
  };
};

export default function fetch({
  namespace,
  isProject,
  overviewCountsAggregationEnabled = false,
  query: { metric },
  queryOverrides: { namespace: namespaceOverride } = {},
  setAlerts,
  setVisualizationOverrides = () => {},
  visualizationOptions = {},
}) {
  const fullPath = namespaceOverride || namespace;
  const { startDate, endDate } = USAGE_OVERVIEW_DEFAULT_DATE_RANGE;
  const variableOverrides = prepareQuery(metric);

  if (!Object.keys(USAGE_OVERVIEW_QUERY_INCLUDE_KEYS).includes(metric)) return '-';

  if (isProject && USAGE_OVERVIEW_GROUP_ONLY_IDENTIFIERS.includes(metric)) {
    setAlerts({
      title: GENERIC_DASHBOARD_ERROR,
      errors: [UNSUPPORTED_PROJECT_NAMESPACE_ERROR],
      canRetry: false,
    });

    return undefined;
  }

  if (!overviewCountsAggregationEnabled) {
    setAlerts({
      title: BACKGROUND_AGGREGATION_WARNING_TITLE,
      description: __('No data available'),
      warnings: [
        {
          description: ENABLE_BACKGROUND_AGGREGATION_WARNING_TEXT,
          link: BACKGROUND_AGGREGATION_DOCS_LINK,
        },
      ],
      canRetry: false,
    });
  }

  const request = defaultClient.query({
    query: getUsageOverviewQuery,
    variables: {
      fullPath,
      startDate: toYmd(startDate),
      endDate: toYmd(endDate),
      ...variableOverrides,
    },
  });

  return request.then(({ data = {} }) => {
    const response = data?.group || data?.project;

    const usageMetricData = extractUsageMetricData({
      metric,
      data: response,
      overviewCountsAggregationEnabled,
    });

    if (!usageMetricData) return '-';

    const { value, visualizationOverrides } = usageMetricData;

    setVisualizationOverrides({
      visualizationOptionOverrides: {
        ...visualizationOverrides,
        ...visualizationOptions,
      },
    });

    return value;
  });
}
