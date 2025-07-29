import { AI_METRICS } from '~/analytics/shared/constants';
import { calculateRate, generateMetricTableTooltip } from './utils';

/**
 * @typedef {Object} TableMetric
 * @property {String} identifier - Identifier for the specified metric
 * @property {Number|'-'} value - Display friendly value
 * @property {String} tooltip - Actual usage rate values to be displayed in tooltip
 */

/**
 * @typedef {Object} AiMetricItem
 * @property {Integer} codeContributorsCount - Number of code contributors
 * @property {Integer} codeSuggestionsContributorsCount - Number of code contributors who used GitLab Duo Code Suggestions features
 * @property {Integer} codeSuggestionsAcceptedCount - Number of code suggestions accepted by code contributors
 * @property {Integer} codeSuggestionsShownCount - Number of code suggestions shown to code contributors
 */

/**
 * @typedef {Object} AiMetricResponseItem
 * @property {TableMetric} code_suggestions_usage_rate
 * @property {TableMetric} code_suggestions_acceptance_rate
 */

/**
 * Takes the raw `aiMetrics` graphql response and prepares the data for display
 * in the table.
 *
 * @param {AiMetricItem} data
 * @returns {AiMetricResponseItem} AI metrics ready for rendering in the dashboard
 */
export const extractGraphqlAiData = ({
  codeContributorsCount = null,
  codeSuggestionsContributorsCount = null,
  codeSuggestionsAcceptedCount = null,
  codeSuggestionsShownCount = null,
  duoChatContributorsCount = null,
  rootCauseAnalysisUsersCount = null,
  duoAssignedUsersCount = null,
} = {}) => {
  const codeSuggestionsUsageRate = calculateRate({
    numerator: codeSuggestionsContributorsCount,
    denominator: codeContributorsCount,
  });

  const codeSuggestionsAcceptanceRate = calculateRate({
    numerator: codeSuggestionsAcceptedCount,
    denominator: codeSuggestionsShownCount,
  });

  const duoChatUsageRate = calculateRate({
    numerator: duoChatContributorsCount,
    denominator: duoAssignedUsersCount,
  });

  const duoRcaUsageRate = calculateRate({
    numerator: rootCauseAnalysisUsersCount,
    denominator: duoAssignedUsersCount,
  });

  return {
    [AI_METRICS.CODE_SUGGESTIONS_USAGE_RATE]: {
      identifier: AI_METRICS.CODE_SUGGESTIONS_USAGE_RATE,
      value: codeSuggestionsUsageRate ?? '-',
      tooltip: generateMetricTableTooltip({
        numerator: codeSuggestionsContributorsCount,
        denominator: codeContributorsCount,
      }),
    },
    [AI_METRICS.CODE_SUGGESTIONS_ACCEPTANCE_RATE]: {
      identifier: AI_METRICS.CODE_SUGGESTIONS_ACCEPTANCE_RATE,
      value: codeSuggestionsAcceptanceRate ?? '-',
      tooltip: generateMetricTableTooltip({
        numerator: codeSuggestionsAcceptedCount,
        denominator: codeSuggestionsShownCount,
      }),
    },
    [AI_METRICS.DUO_CHAT_USAGE_RATE]: {
      identifier: AI_METRICS.DUO_CHAT_USAGE_RATE,
      value: duoChatUsageRate ?? '-',
      tooltip: generateMetricTableTooltip({
        numerator: duoChatContributorsCount,
        denominator: duoAssignedUsersCount,
      }),
    },
    [AI_METRICS.DUO_RCA_USAGE_RATE]: {
      identifier: AI_METRICS.DUO_RCA_USAGE_RATE,
      value: duoRcaUsageRate ?? '-',
      tooltip: generateMetricTableTooltip({
        numerator: rootCauseAnalysisUsersCount,
        denominator: duoAssignedUsersCount,
      }),
    },
  };
};
