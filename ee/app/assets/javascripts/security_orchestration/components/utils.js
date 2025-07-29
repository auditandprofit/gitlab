import { isEmpty, uniqueId } from 'lodash';
import { safeLoad } from 'js-yaml';
import {
  EXCLUDING,
  INCLUDING,
} from 'ee/security_orchestration/components/policy_editor/scope/constants';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import {
  REPORT_TYPE_DEPENDENCY_SCANNING,
  REPORT_TYPE_CONTAINER_SCANNING,
} from '~/vue_shared/security_reports/constants';
import { SCAN_EXECUTION_RULES_SCHEDULE_KEY } from 'ee/security_orchestration/components/policy_editor/scan_execution/constants';
import { POLICY_TYPE_COMPONENT_OPTIONS } from './constants';

export const isPolicyInherited = (source) => source?.inherited === true;

export const policyHasNamespace = (source) => Boolean(source?.namespace);

/**
 * @param policyScope policy scope object on security policy
 * @returns {Boolean}
 */
export const isDefaultMode = (policyScope) => {
  const {
    complianceFrameworks: { nodes: frameworks } = {},
    excludingProjects: { nodes: excluding } = {},
    includingProjects: { nodes: including } = {},
  } = policyScope || {};

  const noScope = (items) => items?.length === 0;
  const existingDefaultScope = noScope(frameworks) && noScope(excluding) && noScope(including);

  return (
    policyScope === undefined ||
    policyScope === null ||
    isEmpty(policyScope) ||
    existingDefaultScope
  );
};

/**
 * Returns true if police scope has projects that are excluded from it
 * @param policyScope policy scope object on security policy
 * @returns {boolean}
 */
export const policyScopeHasExcludingProjects = (policyScope = {}) => {
  const { excludingProjects: { nodes: excluding = [] } = {} } = policyScope || {};
  return excluding?.filter(Boolean).length > 0;
};

/**
 * Returns true if policy scope applies to specific projects
 * @param policyScope policy scope object on security policy
 * @returns {boolean}
 */
export const policyScopeHasIncludingProjects = (policyScope = {}) => {
  const { includingProjects: { nodes: including = [] } = {} } = policyScope || {};
  return including?.filter(Boolean).length > 0;
};

/**
 * Based on existence excluding or including projects on policy scope
 * return appropriate key
 * @param policyScope policyScope policy scope object on security policy
 * @returns {string|INCLUDING|EXCLUDING}
 */
export const policyScopeProjectsKey = (policyScope = {}) => {
  return policyScopeHasIncludingProjects(policyScope) ? INCLUDING : EXCLUDING;
};

/**
 * Based on existence including groups on policy scope
 * return appropriate key
 * @param {Object} policyScope policy scope object on security policy
 * @returns {boolean}
 */
export const policyScopeHasGroups = (policyScope = {}) => {
  const { includingGroups: { nodes = [] } = {} } = policyScope || {};
  return nodes?.filter(Boolean).length > 0;
};

/**
 * Number of linked to policy scope projects
 * @param policyScope policyScope policy scope object on security policy
 * @returns {Number}
 */
export const policyScopeProjectLength = (policyScope = {}) => {
  return (
    policyScope?.[`${policyScopeProjectsKey(policyScope)}Projects`]?.nodes?.filter(Boolean)
      .length || 0
  );
};

/**
 * Check if policy scope has compliance frameworks
 * @param policyScope policyScope policy scope object on security policy
 * @returns {boolean}
 */
export const policyScopeHasComplianceFrameworks = (policyScope = {}) => {
  const { complianceFrameworks: { nodes = [] } = {} } = policyScope || {};
  return nodes?.filter(Boolean).length > 0;
};

/**
 * Extract ids from including groups
 * @param policyScope policyScope policy scope object on security policy
 * @returns {Array}
 */
export const policyScopeGroups = (policyScope = {}) => {
  return policyScope?.includingGroups?.nodes || [];
};

/**
 * Extract ids from excluding projects
 * @param policyScope policyScope policy scope object on security policy
 * @returns {Array}
 */
export const policyExcludingProjects = (policyScope = {}) => {
  return policyScope?.excludingProjects?.nodes || [];
};

/**
 * Extract ids from compliance frameworks
 * @param policyScope policyScope policy scope object on security policy
 * @returns {Array}
 */
export const policyScopeComplianceFrameworks = (policyScope = {}) => {
  return policyScope?.complianceFrameworks?.nodes || [];
};

/**
 * Extract ids from projects
 * @param policyScope policyScope policy scope object on security policy
 * @returns {Object}
 */
export const policyScopeProjects = (policyScope = {}) => {
  const { nodes = [], pageInfo = {} } =
    policyScope?.[`${policyScopeProjectsKey(policyScope)}Projects`] || {};
  return {
    projects: nodes,
    pageInfo,
  };
};

/**
 * Check if namespace is a project type
 * @param namespaceType
 * @returns {boolean}
 */
export const isProject = (namespaceType) => namespaceType === NAMESPACE_TYPES.PROJECT;

/**
 * Check if namespace is a group type
 * @param namespaceType
 * @returns {boolean}
 */
export const isGroup = (namespaceType) => namespaceType === NAMESPACE_TYPES.GROUP;

/**
 * Returns if scanner has "scanning" in it
 * @param {string} scanner
 * @returns {boolean}
 */
export const isScanningReport = (scanner) =>
  [REPORT_TYPE_CONTAINER_SCANNING, REPORT_TYPE_DEPENDENCY_SCANNING].includes(scanner);

/**
 * Policy type, in this case, policy type is a wrapper
 * for a policy content. This method extracts policy content from
 * a wrapper
 * @param manifest policy in yaml format
 * @param type policy type
 * @param withType whether include or not include type property in a policy body
 * @returns {*|{policy: {}}}
 */
export const extractPolicyContent = ({ manifest, type, withType = false }) => {
  const defaultPayload = {};

  try {
    const parsedYaml = safeLoad(manifest, { json: true });

    /**
     * Remove type property from yaml
     * Type now is a parent property
     */
    const hasLegacyTypeRootProperty = 'type' in parsedYaml;
    if (hasLegacyTypeRootProperty) {
      delete parsedYaml.type;
    }

    const hasNewTypeRootProperty = type in parsedYaml;
    const extractedPolicy = hasNewTypeRootProperty ? parsedYaml[type] : parsedYaml;

    const isArray = Array.isArray(extractedPolicy);
    const policy = isArray ? extractedPolicy[0] : extractedPolicy;

    if (withType) {
      policy.type = type;
    }

    return policy || defaultPayload;
  } catch {
    return defaultPayload;
  }
};

export const addIdsToPolicy = (policy) => {
  const updatedPolicy = { ...policy };

  if (updatedPolicy.actions) {
    updatedPolicy.actions = policy.actions?.map((action) => ({
      ...action,
      id: uniqueId('action_'),
    }));
  }

  if (updatedPolicy.rules) {
    updatedPolicy.rules = policy.rules?.map((action) => ({ ...action, id: uniqueId('rule_') }));
  }

  return updatedPolicy;
};

/**
 * Construct a policy object expected by the policy editor from a yaml manifest.
 * @param {Object} options
 * @param {String}  options.manifest a security policy in yaml form
 * @returns {Object} security policy as JS object
 */
export const fromYaml = ({
  manifest,
  type = POLICY_TYPE_COMPONENT_OPTIONS.approval.urlParameter,
  addIds = true,
}) => {
  try {
    const payload = extractPolicyContent({
      manifest,
      type,
      withType: true,
    });

    return addIds ? addIdsToPolicy(payload) : payload;
  } catch {
    /**
     * Catch parsing error of safeLoad
     */
    return {};
  }
};

/**
 * Check if the policy is a scan execution policy and has a scheduled rule
 * @param {Object} policy
 * @returns {Boolean}
 */
export const hasScheduledRule = (policy) => {
  let policyObject = policy;

  // Handle policy list policies
  if (
    policyObject.yaml &&
    // eslint-disable-next-line no-underscore-dangle
    policyObject.__typename === POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.typeName
  ) {
    policyObject = fromYaml({ manifest: policyObject.yaml });
  }

  return policyObject?.rules?.some(({ type }) => type === SCAN_EXECUTION_RULES_SCHEDULE_KEY);
};

export const checkForPerformanceRisk = ({ policy, namespaceType, projectsCount }) => {
  const PROJECTS_COUNT_PERFORMANCE_LIMIT = 1000;

  return (
    hasScheduledRule(policy) &&
    isGroup(namespaceType) &&
    projectsCount > PROJECTS_COUNT_PERFORMANCE_LIMIT
  );
};
