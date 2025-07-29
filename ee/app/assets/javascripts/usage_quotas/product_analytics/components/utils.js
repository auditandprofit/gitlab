import {
  dateAtFirstDayOfMonth,
  nMonthsBefore,
} from '~/lib/utils/datetime/date_calculation_utility';
import { formatDate } from '~/lib/utils/datetime/date_format_utility';

const isValidUsage = ({ year, month, count }) =>
  typeof year === 'number' &&
  typeof month === 'number' &&
  (count === null || typeof count === 'number');

const isValidProject = ({ id, name, avatarUrl, webUrl, productAnalyticsEventsStored }) =>
  typeof id === 'string' &&
  typeof name === 'string' &&
  (avatarUrl === null || typeof avatarUrl === 'string') &&
  typeof webUrl === 'string' &&
  Array.isArray(productAnalyticsEventsStored) &&
  productAnalyticsEventsStored.every(isValidUsage);

/**
 * Validator for the projectsUsageData property
 */
export const projectsUsageDataValidator = (items) => {
  return Array.isArray(items) && items.every(isValidProject);
};

export const monthlyTotalsValidator = (items) => {
  return (
    Array.isArray(items) &&
    items.every(
      ([monthLabel, count]) => typeof monthLabel === 'string' && typeof count === 'number',
    )
  );
};

export const getCurrentMonth = () => {
  return dateAtFirstDayOfMonth(new Date());
};

const findMonthsUsage = (project, monthOffset) => {
  const month = nMonthsBefore(getCurrentMonth(), monthOffset);

  return project.productAnalyticsEventsStored.find(
    (usage) => usage.year === month.getFullYear() && usage.month === month.getMonth() + 1,
  );
};

export const findCurrentMonthUsage = (project) => {
  return findMonthsUsage(project, 0);
};

export const findPreviousMonthUsage = (project) => {
  return findMonthsUsage(project, 1);
};

const formatMonthLabel = (date) => {
  return formatDate(date, 'mmm yyyy');
};

/**
 * Maps projects into an array of monthLabel, numEvents pairs.
 */
export const mapMonthlyTotals = (projects) => {
  const monthlyTotals = {};

  projects.forEach(({ productAnalyticsEventsStored }) =>
    productAnalyticsEventsStored.forEach(({ year, month, count }) => {
      const timestamp = Date.UTC(year, month - 1);
      monthlyTotals[timestamp] = (monthlyTotals[timestamp] || 0) + count;
    }),
  );

  return Array.from(Object.entries(monthlyTotals))
    .map(([timestampString, count]) => [Number(timestampString), count])
    .sort(([timestampA], [timestampB]) => timestampA - timestampB)
    .map(([timestamp, count]) => [formatMonthLabel(new Date(timestamp)), count]);
};

export const findCurrentMonthEventsUsed = (monthlyTotals) => {
  const currentMonthLabel = formatMonthLabel(getCurrentMonth());

  return monthlyTotals?.find(([dateLabel]) => dateLabel === currentMonthLabel)?.at(1);
};
