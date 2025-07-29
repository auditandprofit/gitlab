import { __, sprintf } from '~/locale';
import AiMetricsQuery from 'ee/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql';
import {
  AI_IMPACT_OVER_TIME_METRICS,
  AI_IMPACT_OVER_TIME_METRICS_TOOLTIPS,
} from 'ee/analytics/dashboards/ai_impact/constants';
import { calculateRate } from 'ee/analytics/dashboards/ai_impact/utils';
import {
  LAST_30_DAYS,
  LAST_180_DAYS,
  DORA_METRIC_QUERY_RANGES,
  startOfTomorrow,
} from 'ee/analytics/dora/components/static_data/shared';
import { AI_METRICS } from '~/analytics/shared/constants';
import { scaledValueForDisplay, extractQueryResponseFromNamespace } from '~/analytics/shared/utils';
import { defaultClient } from '../graphql/client';

const DATE_RANGE_TITLES = { [LAST_30_DAYS]: sprintf(__('Last %{days} days'), { days: 30 }) };

const extractMetricData = ({ metric, rawQueryResult: result }) => {
  const resp = extractQueryResponseFromNamespace({
    result,
    resultKey: 'aiMetrics',
  });

  const tooltip = AI_IMPACT_OVER_TIME_METRICS_TOOLTIPS[metric];

  switch (metric) {
    case AI_METRICS.CODE_SUGGESTIONS_USAGE_RATE: {
      const { codeSuggestionsContributorsCount, codeContributorsCount } = resp;
      return {
        rate: calculateRate({
          numerator: codeSuggestionsContributorsCount,
          denominator: codeContributorsCount,
        }),
        tooltip,
      };
    }

    case AI_METRICS.CODE_SUGGESTIONS_ACCEPTANCE_RATE: {
      const { codeSuggestionsAcceptedCount, codeSuggestionsShownCount } = resp;
      return {
        rate: calculateRate({
          numerator: codeSuggestionsAcceptedCount,
          denominator: codeSuggestionsShownCount,
        }),
        tooltip,
      };
    }

    case AI_METRICS.DUO_CHAT_USAGE_RATE: {
      const { duoChatContributorsCount, duoAssignedUsersCount } = resp;
      return {
        rate: calculateRate({
          numerator: duoChatContributorsCount,
          denominator: duoAssignedUsersCount,
        }),
        tooltip,
      };
    }

    case AI_METRICS.DUO_USAGE_RATE: {
      const { duoUsedCount, duoAssignedUsersCount } = resp;
      return {
        rate: calculateRate({
          numerator: duoUsedCount,
          denominator: duoAssignedUsersCount,
        }),
        tooltip,
      };
    }

    default:
      return { rate: null, tooltip: null };
  }
};

const fetchAiImpactQuery = async ({ metric, namespace, startDate, endDate }) => {
  const rawQueryResult = await defaultClient.query({
    query: AiMetricsQuery,
    variables: {
      fullPath: namespace,
      startDate,
      endDate,
    },
  });

  const { rate, tooltip } = extractMetricData({ metric, rawQueryResult });

  if (rate === null)
    return {
      rate: '-',
      tooltip,
    };

  const { units } = AI_IMPACT_OVER_TIME_METRICS[metric];

  return {
    // scaledValueForDisplay expects a value between 0 -> 1
    rate: scaledValueForDisplay(rate / 100, units),
    tooltip,
  };
};

export default async function fetch({
  namespace,
  query: { metric, dateRange = LAST_180_DAYS },
  queryOverrides: { dateRange: dateRangeOverride = null, ...overridesRest } = {},
  setVisualizationOverrides = () => {},
}) {
  const dateRangeKey = dateRangeOverride
    ? dateRangeOverride.toUpperCase()
    : dateRange.toUpperCase();

  // Default to 180 days if an invalid date range is given
  const startDate = DORA_METRIC_QUERY_RANGES[dateRangeKey]
    ? DORA_METRIC_QUERY_RANGES[dateRangeKey]
    : DORA_METRIC_QUERY_RANGES[LAST_180_DAYS];

  const { rate, tooltip } = await fetchAiImpactQuery({
    startDate,
    endDate: startOfTomorrow,
    metric,
    namespace,
    ...overridesRest,
  });

  const visualizationOptionOverrides = {
    ...(DATE_RANGE_TITLES[dateRangeKey] && {
      title: DATE_RANGE_TITLES[dateRangeKey],
    }),
    tooltip,
  };

  setVisualizationOverrides({ visualizationOptionOverrides });

  return rate;
}
