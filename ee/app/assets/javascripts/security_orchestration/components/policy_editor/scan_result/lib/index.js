import {
  BLOCK_BRANCH_MODIFICATION,
  BLOCK_GROUP_BRANCH_MODIFICATION,
  PREVENT_PUSHING_AND_FORCE_PUSHING,
  PREVENT_APPROVAL_BY_AUTHOR,
  PREVENT_APPROVAL_BY_COMMIT_AUTHOR,
  REMOVE_APPROVALS_WITH_NEW_COMMIT,
  REQUIRE_PASSWORD_TO_APPROVE,
} from './settings';

export * from './from_yaml';
export { policyToYaml } from './to_yaml';
export * from './rules';
export * from './actions';
export * from './settings';
export * from './vulnerability_states';
export * from './filters';

export const DEFAULT_SCAN_RESULT_POLICY = `approval_policy:
  - name: ''
    description: ''
    enabled: true
    rules:
      - type: ''
    actions:
      - type: require_approval
        approvals_required: 1
      - type: send_bot_message
        enabled: true
    approval_settings:
      ${BLOCK_BRANCH_MODIFICATION}: true
      ${PREVENT_PUSHING_AND_FORCE_PUSHING}: true
      ${PREVENT_APPROVAL_BY_AUTHOR}: true
      ${PREVENT_APPROVAL_BY_COMMIT_AUTHOR}: true
      ${REMOVE_APPROVALS_WITH_NEW_COMMIT}: true
      ${REQUIRE_PASSWORD_TO_APPROVE}: false
    fallback_behavior:
      fail: closed
`;

export const DEFAULT_SCAN_RESULT_POLICY_WITH_SCOPE_WITH_GROUP_SETTINGS = `approval_policy:
  - name: ''
    description: ''
    enabled: true
    policy_scope:
      projects:
        excluding: []
    rules:
      - type: ''
    actions:
      - type: require_approval
        approvals_required: 1
      - type: send_bot_message
        enabled: true
    approval_settings:
      ${BLOCK_BRANCH_MODIFICATION}: true
      ${BLOCK_GROUP_BRANCH_MODIFICATION}: true
      ${PREVENT_PUSHING_AND_FORCE_PUSHING}: true
      ${PREVENT_APPROVAL_BY_AUTHOR}: true
      ${PREVENT_APPROVAL_BY_COMMIT_AUTHOR}: true
      ${REMOVE_APPROVALS_WITH_NEW_COMMIT}: true
      ${REQUIRE_PASSWORD_TO_APPROVE}: false
    fallback_behavior:
      fail: closed
`;

export const getPolicyYaml = ({ isGroup }) =>
  isGroup ? DEFAULT_SCAN_RESULT_POLICY_WITH_SCOPE_WITH_GROUP_SETTINGS : DEFAULT_SCAN_RESULT_POLICY;
