import { isNil } from 'lodash';
import { isNumeric } from '~/lib/utils/number_utils';
import { formatNumber, n__, __, sprintf } from '~/locale';
import { formatDate, humanizeTimeInterval } from '~/lib/utils/datetime/date_format_utility';
import { formatAsPercentage } from 'ee/analytics/dora/components/util';
import { NULL_SERIES_ID } from 'ee/analytics/shared/constants';
import { UNITS } from '~/analytics/shared/constants';

function isIsoDateString(dateString) {
  // Matches an ISO date string in the format `2024-03-14T00:00:00.000`
  const isoDateRegex = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}$/;
  return isoDateRegex.test(dateString);
}

export function formatVisualizationValue(value) {
  if (isIsoDateString(value)) {
    return formatDate(value);
  }

  if (isNumeric(value)) {
    return formatNumber(parseInt(value, 10));
  }

  return value;
}

export function formatVisualizationTooltipTitle(title, params) {
  const value = params?.seriesData?.at(0)?.value?.at(0);

  if (isIsoDateString(value)) {
    const formattedDate = formatDate(value);
    return title.replace(value, formattedDate);
  }

  return title;
}

export function customFormatVisualizationTooltipTitle(params, formatter) {
  const xAxisValue = params?.seriesData?.at(0)?.value?.at(0);

  if (isNil(xAxisValue)) return '';

  return formatter(xAxisValue);
}

export const humanizeDisplayUnit = ({ unit, data = 0 }) => {
  switch (unit) {
    case 'days':
      return n__('day', 'days', data === '-' ? 0 : data);
    case 'per_day':
      return __('/day');
    case 'percent':
      return '%';
    default:
      return unit;
  }
};

/**
 * Humanizes values to be displayed in chart tooltips
 *
 * @param {string} unit – The unit of measurement to be used for metric
 * @param {number} value - The value of the metric
 * @returns {string|number} - Humanized tooltip value
 */
export const humanizeChartTooltipValue = ({ unit, value } = {}) => {
  if (isNil(value)) return __('No data');

  switch (unit) {
    case UNITS.DAYS:
      return n__('%d day', '%d days', value);
    case UNITS.PER_DAY:
      return sprintf(__('%{value} /day'), { value });
    case UNITS.PERCENT:
      return formatAsPercentage(value);
    case UNITS.TIME_INTERVAL:
      return humanizeTimeInterval(value);
    default:
      return value;
  }
};

export const calculateDecimalPlaces = ({ data, decimalPlaces } = {}) => {
  return (data && parseInt(decimalPlaces, 10)) || 0;
};

export const removeNullSeries = (seriesData) => {
  return seriesData?.filter(({ seriesId }) => seriesId !== NULL_SERIES_ID);
};
