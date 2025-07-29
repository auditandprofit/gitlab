import { isNumeric } from '~/lib/utils/number_utils';
import { DAILY, WEEKLY, MONTHLY } from '../constants';
import { CADENCE_CONFIG, MAXIMUM_SECONDS, MINIMUM_SECONDS, TIME_UNITS } from './constants';

export const isCadenceWeekly = (cadence) => cadence === WEEKLY;
export const isCadenceMonthly = (cadence) => cadence === MONTHLY;

/**
 * Ensures the time is within the limits
 * @param {number} time - Time value in seconds
 * @returns {number} Time value capped between MINIMUM_SECONDS and MAXIMUM_SECONDS
 */
export const getValueWithinLimits = (time) => {
  return Math.max(Math.min(time, MAXIMUM_SECONDS), MINIMUM_SECONDS);
};

export const updateScheduleCadence = ({ schedule, cadence }) => {
  const { days, days_of_month, ...updatedSchedule } = schedule;
  updatedSchedule.type = cadence;

  if (CADENCE_CONFIG[cadence]) {
    Object.assign(updatedSchedule, {
      ...CADENCE_CONFIG[cadence],
      time_window: {
        ...updatedSchedule.time_window,
        value: CADENCE_CONFIG[cadence].time_window.value,
      },
    });
  }

  return updatedSchedule;
};

/**
 * Generate options for monthly day selection
 * @returns {Array} Array of day options
 */
export const getMonthlyDayOptions = () => {
  return Array.from({ length: 31 }, (_, i) => {
    const day = i + 1;
    return { value: day, text: day };
  });
};

/**
 * Validates a cadence value to ensure it's one of the supported options
 * @param {string} cadence
 * @returns {Boolean}
 */
export const isValidCadence = (cadence) => [DAILY, WEEKLY, MONTHLY].includes(cadence);

/**
 * Converts a value and time unit to seconds
 * @param {Number} value - The numeric value
 * @param {Number} unit - The time unit in seconds (from TIME_UNITS)
 * @returns {Number} Total seconds
 */
export const timeUnitToSeconds = (value, unit) => {
  return value * unit;
};

/**
 * Converts seconds to a value in the specified unit
 * @param {Number} seconds
 * @param {Number} unit - The time unit to convert to
 * @returns {Number} Value in the specified unit
 */
export const secondsToValue = (seconds, unit) => {
  if (!isNumeric(seconds) || seconds < 0) {
    return 0;
  }

  return seconds / unit;
};

/**
 * Determines the most appropriate time unit for a given number of seconds
 * @param {Number} seconds
 * @returns {Number} The appropriate time unit from TIME_UNITS
 */
export const determineTimeUnit = (seconds) => {
  if (!isNumeric(seconds) || seconds < 0) {
    return TIME_UNITS.MINUTE;
  }

  if (seconds % TIME_UNITS.DAY === 0 && seconds >= TIME_UNITS.DAY) {
    return TIME_UNITS.DAY;
  }

  if (seconds % TIME_UNITS.HOUR === 0 && seconds >= TIME_UNITS.HOUR) {
    return TIME_UNITS.HOUR;
  }

  return TIME_UNITS.MINUTE;
};
