import { uniqueId, get } from 'lodash';
import {
  ACCOUNTS,
  EXCEPTIONS_FULL_OPTIONS_MAP,
  GROUPS,
  ROLES,
  TOKENS,
  USERS,
} from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/constants';

export const createSourceBranchPatternObject = ({ id = '', source = {}, target = {} } = {}) => ({
  id: id || uniqueId('pattern_'),
  source,
  target,
});

export const createServiceAccountObject = ({ id = '' } = {}) => ({
  id: id || uniqueId('account_'),
});
/**
 * Extract username from account
 * @param item
 * @returns {*}
 */
export const getUserName = (item) => get(item, 'account.username', '');

/**
 * validate that account has all required properties
 * @param item
 * @returns {boolean}
 */
export const isValidServiceAccount = (item) => item && Boolean(item.name) && Boolean(item.username);

/**
 * remove ids from items
 * @param items
 * @returns {*[]}
 */
export const removeIds = (items = []) => {
  return items.map(({ id, ...item }) => ({ ...item }));
};

export const renderOptionsList = ({
  securityPoliciesBypassOptionsTokensAccounts = false,
  securityPoliciesBypassOptionsGroupRoles = false,
}) => {
  const allOptions = { ...EXCEPTIONS_FULL_OPTIONS_MAP };

  if (!securityPoliciesBypassOptionsTokensAccounts) {
    delete allOptions[ACCOUNTS];
    delete allOptions[TOKENS];
  }

  if (!securityPoliciesBypassOptionsGroupRoles) {
    delete allOptions[ROLES];
    delete allOptions[GROUPS];
    delete allOptions[USERS];
  }

  return allOptions;
};

/**
 * Filter out invalid exceptions keys
 * @param keys
 * @returns {string[]};
 */
export const onlyValidKeys = (keys) => {
  const { securityPoliciesBypassOptionsTokensAccounts, securityPoliciesBypassOptionsGroupRoles } =
    window.gon?.features || {};

  const validKeys = Object.keys(
    renderOptionsList({
      securityPoliciesBypassOptionsTokensAccounts,
      securityPoliciesBypassOptionsGroupRoles,
    }),
  );
  return keys.filter((key) => validKeys.includes(key));
};
