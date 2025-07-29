import { __ } from '~/locale';
import { getWeekdayNames } from '~/lib/utils/datetime_utility';
import { DAILY } from '../constants';

export const DEFAULT_TIMEZONE = 'Etc/UTC';
export const DEFAULT_START_WEEKDAY = 'Monday';
export const DEFAULT_START_MONTH_DAY = 1;
export const WEEKLY = 'weekly';
export const MONTHLY = 'monthly';
export const MINIMUM_SECONDS = 600; // 10 minutes, set in ee/app/validators/json_schemas/security_orchestration_policy.json
export const MINIMUM_SECONDS_IN_MINUTES = MINIMUM_SECONDS / 60;
export const MAXIMUM_SECONDS = 2629746; // 30 days, set in ee/app/validators/json_schemas/security_orchestration_policy.json

export const CADENCE_OPTIONS = [
  { value: DAILY, text: __('Daily') },
  { value: WEEKLY, text: __('Weekly') },
  { value: MONTHLY, text: __('Monthly') },
];

// Constants for time units in seconds
export const TIME_UNITS = {
  MINUTE: 60,
  HOUR: 3600,
  DAY: 86400, // 24 hours * 60 minutes * 60 seconds
};

export const CADENCE_CONFIG = {
  [DAILY]: {
    time_window: { value: TIME_UNITS.MINUTE },
  },
  [WEEKLY]: {
    days: [DEFAULT_START_WEEKDAY],
    time_window: { value: TIME_UNITS.DAY },
  },
  [MONTHLY]: {
    days_of_month: [DEFAULT_START_MONTH_DAY],
    time_window: { value: TIME_UNITS.DAY },
  },
};

export const TIME_UNIT_OPTIONS = [
  { value: TIME_UNITS.MINUTE, text: __('Minutes') },
  { value: TIME_UNITS.HOUR, text: __('Hours') },
  { value: TIME_UNITS.DAY, text: __('Days') },
];

// Constants for time units in seconds
export const DEFAULT_TIME_PER_UNIT = {
  [TIME_UNITS.MINUTE]: MINIMUM_SECONDS,
  [TIME_UNITS.HOUR]: TIME_UNITS.HOUR,
  [TIME_UNITS.DAY]: TIME_UNITS.DAY,
};

/**
 * Time options in one hour increments for the daily scheduler
 * @returns {Array} Array of time options
 */
export const HOUR_MINUTE_LIST = Array.from(Array(24).keys()).map((num) => {
  const hour = num.toString().length === 1 ? `0${num}:00` : `${num}:00`;
  return { value: hour, text: hour };
});

/**
 * Weekday options for the weekly scheduler
 * @returns {Array} Array of weekday options
 */
export const WEEKDAY_OPTIONS = getWeekdayNames().map((day) => {
  return { value: day, text: day };
});
