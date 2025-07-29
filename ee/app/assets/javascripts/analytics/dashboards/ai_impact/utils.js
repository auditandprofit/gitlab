import { isNil } from 'lodash';
import { __, s__, sprintf } from '~/locale';
import {
  getStartOfDay,
  dateAtFirstDayOfMonth,
  nMonthsBefore,
  nSecondsBefore,
  formatDate,
} from '~/lib/utils/datetime_utility';
import { isPositiveInteger } from '~/lib/utils/number_utils';
import { formatMetric, percentChange, isMetricInTimePeriods } from '../utils';
import { AI_IMPACT_TABLE_METRICS } from './constants';

const getColumnKeyForMonth = (monthsAgo) => `${monthsAgo}-months-ago`;
const getStartOfMonth = (now) => dateAtFirstDayOfMonth(getStartOfDay(now));

/**
 * Generates the time period columns, from This month -> 5 months ago.
 *
 * @param {Date} now Current date
 * @returns {Array} Tuple of time periods
 */
export const generateDateRanges = (now) => {
  const formatDateHeader = (date) => formatDate(date, 'mmm yyyy');

  const currentMonth = {
    key: 'this-month',
    label: formatDateHeader(now),
    start: getStartOfMonth(now),
    end: now,
    thClass: 'gl-w-1/10',
  };

  return [1, 2, 3, 4, 5].reduce(
    (acc, nMonth) => {
      const thisMonthStart = getStartOfMonth(now);
      const start = nMonthsBefore(thisMonthStart, nMonth);
      const end = nSecondsBefore(nMonthsBefore(thisMonthStart, nMonth - 1), 1);
      return [
        {
          key: getColumnKeyForMonth(nMonth),
          label: formatDateHeader(start),
          start,
          end,
          thClass: 'gl-w-1/10',
        },
        ...acc,
      ];
    },
    [currentMonth],
  );
};

/**
 * Generates all the table columns based on the given date.
 *
 * @param {Date} now
 * @returns {Array} The list of columns
 */
export const generateTableColumns = (now) => [
  {
    key: 'metric',
    label: __('Metric'),
    thClass: 'gl-w-3/20',
  },
  ...generateDateRanges(now),
  {
    key: 'change',
    label: sprintf(__('Change (%%)')),
    description: __('Past 6 Months'),
    thClass: 'gl-w-3/20',
  },
  {
    key: 'chart',
    label: __('Trend'),
    start: nMonthsBefore(now, 6),
    end: now,
    thClass: 'gl-w-1/10',
    tdClass: '!gl-py-2',
  },
];

/**
 * Creates the table rows filled with blank data. Once the data has loaded,
 * it can be filled into the returned skeleton using `mergeTableData`.
 *
 * @param {Array} excludeMetrics - Array of metric identifiers to remove from the table
 * @returns {Array} array of data-less table rows
 */
export const generateSkeletonTableData = (excludeMetrics = []) =>
  Object.entries(AI_IMPACT_TABLE_METRICS)
    .filter(([identifier]) => !excludeMetrics.includes(identifier))
    .map(([identifier, { label, invertTrendColor }]) => ({
      metric: { identifier, value: label },
      invertTrendColor,
    }));

export const calculateChange = (current, previous) => {
  const isInvalid = (value) => isNil(value) || value === '-';

  if (isInvalid(current) && isInvalid(previous)) {
    return { value: __('n/a'), tooltip: __('No data available') };
  }

  if (isInvalid(current) || isInvalid(previous)) {
    return {
      value: __('n/a'),
      tooltip: s__("AiImpactAnalytics|Value can't be calculated due to insufficient data."),
    };
  }

  if (Number(previous) === 0 && Number(current) === 0) {
    return { value: 0, tooltip: __('No change') };
  }

  if (Number(previous) === 0) {
    return {
      value: __('n/a'),
      tooltip: s__("AiImpactAnalytics|Value can't be calculated due to division by zero."),
    };
  }

  // Either 100% or -100%, depending on the previous value
  if (Number(current) === 0) {
    return { value: -Math.sign(previous) };
  }

  const value = percentChange({ current, previous });
  if (value === 0) {
    return { value, tooltip: __('No change') };
  }

  return { value };
};

/**
 * Takes N time periods for a single metric and generates the row for the table.
 *
 * @param {String} identifier - ID of the metric to create a table row for.
 * @param {String} units - The type of units used for this metric (ex. days, /day, count)
 * @param {Array} timePeriods - Array of the metrics for different time periods
 * @returns {Object} The metric data formatted as a table row.
 */
const buildTableRow = ({ identifier, units, timePeriods }) => {
  const row = timePeriods.reduce((acc, timePeriod) => {
    const metric = timePeriod[identifier];
    return Object.assign(acc, {
      [timePeriod.key]: {
        value: metric?.value !== '-' ? formatMetric(metric.value, units) : '-',
        tooltip: metric?.tooltip,
      },
    });
  }, {});

  const firstMonth = timePeriods.find((timePeriod) => timePeriod.key === getColumnKeyForMonth(1));
  const lastMonth = timePeriods.find((timePeriod) => timePeriod.key === getColumnKeyForMonth(5));
  const change = calculateChange(firstMonth[identifier]?.value, lastMonth[identifier]?.value);

  return { ...row, change };
};

/**
 * Takes N time periods of metrics and formats the data to be displayed in the table.
 *
 * @param {Array} timePeriods - Array of metrics for different time periods
 * @returns {Object} object containing the same data, formatted for the table
 */
export const generateTableRows = (timePeriods) =>
  Object.entries(AI_IMPACT_TABLE_METRICS).reduce((acc, [identifier, { units }]) => {
    if (!isMetricInTimePeriods(identifier, timePeriods)) return acc;

    return Object.assign(acc, {
      [identifier]: buildTableRow({
        identifier,
        units,
        timePeriods,
      }),
    });
  }, {});

/**
 * Calculates a rate, given a numerator and a denominator
 * returns null if the values given are invalid, or a division by 0 is attempted
 *
 * @param {number} numerator - The value to be divided (above the line)
 * @param {number} denominator - The number to be divided by (below the line)
 * @returns {number|null} - Percentage or null if either count is invalid
 */
export const calculateRate = ({ numerator, denominator }) => {
  const hasValidCounts =
    isPositiveInteger(numerator) && isPositiveInteger(denominator) && denominator > 0;

  if (!hasValidCounts) return null;

  return (numerator / denominator) * 100;
};

/**
 * @typedef {Array<String>} MetricIds
 */

/**
 * @typedef {Array<[String, MetricIds]>} AlertGroup
 */

/**
 * Creates a list of panel alerts to be rendered for the metric table.
 *
 * @param {Array<AlertGroup>} alertGroups - In the format [message, metrics]. The list of
 *    potential alerts to show, if there are any metrics present.
 * @returns {Array<String>} The list of alerts to be rendered for the metric table.
 */
export const generateTableAlerts = (alertGroups) =>
  alertGroups.reduce((alerts, [message, metrics]) => {
    if (metrics.length === 0) return alerts;

    const formattedMetrics = metrics.map((metric) => AI_IMPACT_TABLE_METRICS[metric].label);
    return [...alerts, `${message}: ${formattedMetrics.join(', ')}`];
  }, []);

/**
 * Generates a string with a rate's numerator and denominator to be used
 * in the metric table's tooltips.
 * @param {number} numerator
 * @param {number} denominator
 * @returns {String|'No data'} The rate's raw values as a fraction. If the rate is `null`, returns 'No data.'
 */
export const generateMetricTableTooltip = ({ numerator, denominator }) => {
  const rate = calculateRate({ numerator, denominator });

  if (rate === null) return __('No data');

  return `${numerator}/${denominator}`;
};
