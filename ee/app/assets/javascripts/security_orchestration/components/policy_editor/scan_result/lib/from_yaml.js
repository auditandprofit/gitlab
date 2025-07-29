import { isBoolean, isEmpty, isEqual } from 'lodash';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import { fromYaml } from 'ee/security_orchestration/components/utils';
import { hasInvalidKey } from '../../utils';
import { OPEN, CLOSED } from '../advanced_settings/constants';
import { hasInvalidRules } from './rules';
import {
  BLOCK_GROUP_BRANCH_MODIFICATION,
  VALID_APPROVAL_SETTINGS,
  PERMITTED_INVALID_SETTINGS,
  PERMITTED_INVALID_SETTINGS_KEY,
} from './settings';

/**
 * Validate policy properties that would break rule mode
 * @param {Object} policy
 * @returns {Object} Errors object. If empty, policy is valid.
 */
export const validatePolicy = (policy) => {
  if (isEmpty(policy)) {
    return {
      actions: true,
      rules: true,
      fallback: true,
      settings: true,
    };
  }

  const error = {};
  if (hasInvalidRules(policy.rules)) {
    error.rules = true;
  }

  const { approval_settings: settings = {}, fallback_behavior: fallback = {} } = policy;

  // Temporary workaround to allow the rule builder to load with wrongly persisted settings
  const hasInvalidApprovalSettings = hasInvalidKey(settings, [
    ...VALID_APPROVAL_SETTINGS,
    PERMITTED_INVALID_SETTINGS_KEY,
  ]);

  const hasInvalidSettingStructure = () => {
    if (isEqual(settings, PERMITTED_INVALID_SETTINGS)) {
      return false;
    }

    return !Object.entries(settings).every(
      ([key, value]) => isBoolean(value) || key === BLOCK_GROUP_BRANCH_MODIFICATION,
    );
  };

  if (hasInvalidApprovalSettings || hasInvalidSettingStructure()) {
    error.settings = true;
  }

  const hasInvalidFallbackBehavior = !isEmpty(fallback) && ![OPEN, CLOSED].includes(fallback.fail);

  if (hasInvalidFallbackBehavior) {
    error.fallback = true;
  }

  if (hasInvalidRules(policy.rules)) {
    error.rules = true;
  }

  return error;
};

/**
 * Converts a security policy from yaml to an object
 * @param {String} manifest a security policy in yaml form
 * @returns {Object} security policy object and any errors
 */
export const createPolicyObject = (manifest) => {
  const policy = fromYaml({ manifest, type: POLICY_TYPE_COMPONENT_OPTIONS.approval.urlParameter });
  const parsingError = validatePolicy(policy);

  return { policy, parsingError };
};
