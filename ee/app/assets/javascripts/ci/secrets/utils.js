import { ROTATION_PERIOD_OPTIONS } from './constants';

/**
 * This function converts the rotation period to the the appropriate
 * text to use in the UI. If there is no match, we return the
 * rotationPeriod by default, since this could be a custom CRON.
 * @param {String} rotationPeriod
 * @returns {String} - Converted UI text, if applicable
 */

export const convertRotationPeriod = (rotationPeriod = '') => {
  const selectedRotationPeriod = ROTATION_PERIOD_OPTIONS.find(
    (item) => item.value === rotationPeriod,
  );
  return selectedRotationPeriod?.text || rotationPeriod;
};
