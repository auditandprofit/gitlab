import { isEqual, uniqueId } from 'lodash';
import { s__ } from '~/locale';
import { SPECIFIC_BRANCHES } from 'ee/security_orchestration/components/policy_editor/constants';
import { policyBodyToYaml } from '../../utils';
import {
  DEFAULT_CONDITION_STRATEGY,
  SCAN_EXECUTION_PIPELINE_RULE,
  SCAN_EXECUTION_SCHEDULE_RULE,
} from '../constants';
import { CRON_DEFAULT_TIME } from './cron';

export const buildDefaultPipeLineRule = () => {
  return {
    id: uniqueId('rule_'),
    type: SCAN_EXECUTION_PIPELINE_RULE,
    branches: ['*'],
  };
};

export const buildDefaultScheduleRule = () => {
  return {
    id: uniqueId('rule_'),
    type: SCAN_EXECUTION_SCHEDULE_RULE,
    branches: [],
    cadence: CRON_DEFAULT_TIME,
  };
};

export const RULE_KEY_MAP = {
  [SCAN_EXECUTION_PIPELINE_RULE]: buildDefaultPipeLineRule,
  [SCAN_EXECUTION_SCHEDULE_RULE]: buildDefaultScheduleRule,
};

/**
 * Handles branch type selection and updates the rule accordingly
 *
 * @param {Object} options
 * @param {string} options.branchType - The selected branch type
 * @param {Object} options.rule - The current rule object
 * @param {string} options.pipelineRuleKey - The key identifying pipeline rules
 * @param {Array<string>} options.targetBranches - Branch types that support pipeline sources
 * @returns {Object} The updated rule object
 */
export const handleBranchTypeSelect = ({ branchType, rule, pipelineRuleKey }) => {
  let updatedRule;

  /**
   * Either branch or branch_type property are allowed on rule object
   * Based on value we remove one and set another and vice versa
   */
  if (branchType === SPECIFIC_BRANCHES.value) {
    /**
     * Pipeline rule and Schedule rule have different default values
     * Pipeline rule supports wildcard for branches
     */
    const branches = rule.type === pipelineRuleKey ? ['*'] : [];
    updatedRule = { ...rule, branches };
    delete updatedRule.branch_type;
  } else {
    updatedRule = { ...rule, branch_type: branchType };
    delete updatedRule.branches;
  }

  delete updatedRule.pipeline_sources;
  return updatedRule;
};

export const STRATEGIES = [
  {
    key: DEFAULT_CONDITION_STRATEGY,
    header: s__('SecurityOrchestration|Merge Request Security'),
    description: s__(
      'SecurityOrchestration|Run scans for merge request pipelines targeting default branches and on default branches. Optimized for MR approval policy compatibility',
    ),
    rules: [
      { type: 'pipeline', branch_type: 'default' },
      {
        type: 'pipeline',
        branch_type: 'target_default',
        pipeline_sources: { including: ['merge_request_event'] },
      },
    ],
  },
  {
    key: 'scheduled',
    header: s__('SecurityOrchestration|Scheduled Scanning'),
    description: s__(
      'SecurityOrchestration|Runs scans on a schedule for maintenance and continuous monitoring of protected branches',
    ),
    rules: [
      {
        type: 'schedule',
        cadence: '0 0 * * *',
        branch_type: 'protected',
        timezone: 'Etc/UTC',
        time_window: { distribution: 'random', value: 36000 },
      },
    ],
  },
  {
    key: 'release',
    header: s__('SecurityOrchestration|Merge Release Security'),
    description: s__(
      'SecurityOrchestration|Runs comprehensive scans for `release/*` branches and when merging to main/production branches',
    ),
    rules: [
      { type: 'pipeline', branches: ['release/*'] },
      { type: 'pipeline', branch_type: 'default' },
    ],
  },
];

export const STRATEGIES_RULE_MAP = STRATEGIES.reduce((acc, curr) => {
  acc[curr.key] = curr.rules;
  return acc;
}, {});

export const hasPredefinedRuleStrategy = (rules) => {
  const rulesYaml = policyBodyToYaml({ rules });
  return STRATEGIES.map((strategy) => policyBodyToYaml({ rules: strategy.rules })).some(
    (strategyYaml) => isEqual(strategyYaml, rulesYaml),
  );
};
